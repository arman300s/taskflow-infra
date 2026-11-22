variable "region" {
  description = "OCI region"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "compartment_ocid" {
  description = "Compartment for all resources (the root compartment = tenancy OCID)"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Public key that is allowed to log in as ubuntu on every server"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "name_suffix" {
  description = "Change it (e.g. to -v2) to make OpenTofu replace all servers with new ones"
  type        = string
  default     = ""
}

variable "ad_number" {
  description = "Availability domain (1-3). Free Ampere capacity differs between them - change it on 'Out of host capacity'"
  type        = number
  default     = 1
}

variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "servers" {
  description = "The TaskFlow servers: role, fixed private IP, shape and size"
  type = map(object({
    role       = string
    private_ip = string
    shape      = string
    ocpus      = optional(number) # only for Flex shapes
    memory_gb  = optional(number)
    disk_gb    = number
    ad         = optional(number) # pinned availability domain, null = var.ad_number
  }))
  # Always Free limits of this tenancy (checked with oci_limits_limit_values):
  #   VM.Standard.A1.Flex (Ampere ARM) - 2 OCPU in total
  #   VM.Standard.E2.1.Micro (AMD x86, 1 OCPU / 1 GB) - 2 servers, only in AD-2
  default = {
    tf-web = { role = "web", private_ip = "10.0.0.21",  shape = "VM.Standard.E2.1.Micro", disk_gb = 50, ad = 2 }
    tf-app = { role = "app", private_ip = "10.0.0.209", shape = "VM.Standard.A1.Flex",    ocpus = 1, memory_gb = 6,  disk_gb = 50 }
    tf-db  = { role = "db",  private_ip = "10.0.0.165", shape = "VM.Standard.E2.1.Micro", disk_gb = 50, ad = 2 }
  }
}
