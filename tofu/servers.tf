data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# newest official Canonical Ubuntu 24.04 image for every shape in use (ARM and x86 builds differ)
data "oci_core_images" "ubuntu" {
  for_each                 = toset([for s in var.servers : s.shape])
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = each.value
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "server" {
  for_each = var.servers

  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[coalesce(each.value.ad, var.ad_number) - 1].name
  display_name        = "${each.key}${var.name_suffix}"
  shape               = each.value.shape

  dynamic "shape_config" {
    for_each = endswith(each.value.shape, ".Flex") ? [1] : []
    content {
      ocpus         = each.value.ocpus
      memory_in_gbs = each.value.memory_gb
    }
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu[each.value.shape].images[0].id
    boot_volume_size_in_gbs = each.value.disk_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    private_ip       = each.value.private_ip
    hostname_label   = each.key
  }

  metadata = {
    ssh_authorized_keys = file(pathexpand(var.ssh_public_key_path))
  }

  freeform_tags = { project = "taskflow", role = each.value.role }

  # a server that already exists stays in its availability domain when ad_number is changed
  # to create the missing ones elsewhere (the subnet is regional, so they can still talk)
  lifecycle {
    ignore_changes = [availability_domain, source_details[0].source_id]
  }
}

# Ansible inventory generated from the real addresses of the new servers
resource "local_file" "inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.yml"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.tftpl", {
    servers = {
      for name, s in var.servers : name => {
        role       = s.role
        public_ip  = oci_core_instance.server[name].public_ip
        private_ip = oci_core_instance.server[name].private_ip
      }
    }
    ssh_key = trimsuffix(var.ssh_public_key_path, ".pub")
  })
}

# SSH aliases (ssh tf-web | tf-app | tf-db) for the new addresses; ~/.ssh/config includes this file
resource "local_file" "ssh_config" {
  filename        = "${path.module}/ssh_config"
  file_permission = "0644"
  content = join("\n", [for name, s in var.servers : <<-EOT
    Host ${name}
        HostName ${oci_core_instance.server[name].public_ip}
        User ubuntu
        IdentityFile ${trimsuffix(var.ssh_public_key_path, ".pub")}
        StrictHostKeyChecking accept-new
        UserKnownHostsFile ~/.ssh/known_hosts_taskflow
    EOT
  ])
}
