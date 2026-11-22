# Virtual Cloud Network with one public subnet; servers talk to each other over private IPs
resource "oci_core_vcn" "taskflow" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "taskflow-vcn"
  dns_label      = "taskflow"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.taskflow.id
  display_name   = "taskflow-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.taskflow.id
  display_name   = "taskflow-public-rt"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Layer 1 of the firewall (cloud level). Layer 2 is UFW on every server (Ansible).
resource "oci_core_security_list" "taskflow" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.taskflow.id
  display_name   = "taskflow-security-list"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # public: SSH (keys only, rate-limited by UFW) and HTTP to tf-web
  dynamic "ingress_security_rules" {
    for_each = { ssh = 22, http = 80 }
    content {
      source      = "0.0.0.0/0"
      protocol    = "6" # TCP
      description = ingress_security_rules.key
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }

  # private network only: API, PostgreSQL, node_exporter
  dynamic "ingress_security_rules" {
    for_each = { api = 8000, postgresql = 5432, metrics = 9100 }
    content {
      source      = var.vcn_cidr
      protocol    = "6"
      description = ingress_security_rules.key
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }

  # ICMP "destination unreachable / fragmentation needed" (path MTU discovery)
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "1"
    icmp_options {
      type = 3
      code = 4
    }
  }
  ingress_security_rules {
    source   = var.vcn_cidr
    protocol = "1"
    icmp_options { type = 3 }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.taskflow.id
  cidr_block        = var.subnet_cidr
  display_name      = "taskflow-public-subnet"
  dns_label         = "public"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.taskflow.id]
}
