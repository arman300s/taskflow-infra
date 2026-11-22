output "servers" {
  description = "Public and private address of every server"
  value = {
    for name, i in oci_core_instance.server : name => {
      public_ip  = i.public_ip
      private_ip = i.private_ip
      shape      = "${i.shape} (${i.shape_config[0].ocpus} OCPU, ${i.shape_config[0].memory_in_gbs} GB) in ${i.availability_domain}"
      ssh        = "ssh ubuntu@${i.public_ip}"
    }
  }
}

output "images" {
  value = { for shape, d in data.oci_core_images.ubuntu : shape => d.images[0].display_name }
}

output "website" {
  value = "http://${oci_core_instance.server["tf-web"].public_ip}"
}
