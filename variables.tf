# AVX Cloud Accounts
variable "aviatrix_admin_account" { 
  default = "admin"
}

variable "aviatrix_admin_password" { 
  description = "Aviatrix admin user password"
}

variable "aviatrix_controller_ip" { 
  description = "Aviatrix Controller IP or FQDN"
}

variable "ssh_key" {
  description = "SSH key used for test clients"
}

variable "gcp_account_name" {
  description = "GCP Project account name as defined in the Controller"
}

# GCP
/* variable "gcp_creds" { 
  default = "gcp.json"
}

variable "gcp_project" { 
  description = "GCP Project Name"
} */

variable "psk" { 
  description = "Preshared Key for tunnels between spoke and transit"
}

variable "gw_size" {
  description = "Gateway instance size"
  default = "n1-highcpu-4"
}
