# Deploy Transit
resource "aviatrix_vpc" "transit" {
  cloud_type   = 4
  account_name = var.gcp_account_name
  name         = "trans-vpc"

  subnets {
    name   = "trans-subnet-1"
    region = "europe-west1"
    cidr   = "10.10.0.0/26"
  }

  subnets {
    name   = "trans-subnet-2"
    region = "europe-west3"
    cidr   = "10.10.0.64/26"
  }
}

# Create an Aviatrix Transit Network Gateway - Region 1
resource "aviatrix_transit_gateway" "trans1" {
  cloud_type                = 4
  account_name              = var.gcp_account_name
  gw_name                   = "trans1-gw"
  vpc_id                    = aviatrix_vpc.transit.name
  vpc_reg                   = "${aviatrix_vpc.transit.subnets[0].region}-b"
  gw_size                   = var.gw_size
  subnet                    = aviatrix_vpc.transit.subnets[0].cidr
  enable_active_mesh        = true
  enable_multi_tier_transit = true
  local_as_number           = 65001
  bgp_ecmp                  = true
  ha_zone                   = "${aviatrix_vpc.transit.subnets[0].region}-c"
  ha_subnet                 = aviatrix_vpc.transit.subnets[0].cidr
  ha_gw_size                = var.gw_size
}
# Create an Aviatrix Transit Network Gateway - Region 2
resource "aviatrix_transit_gateway" "trans2" {
  cloud_type                = 4
  account_name              = var.gcp_account_name
  gw_name                   = "trans2-gw"
  vpc_id                    = aviatrix_vpc.transit.name
  vpc_reg                   = "${aviatrix_vpc.transit.subnets[1].region}-b"
  gw_size                   = var.gw_size
  subnet                    = aviatrix_vpc.transit.subnets[1].cidr
  enable_active_mesh        = true
  enable_multi_tier_transit = true
  local_as_number           = 65002
  bgp_ecmp                  = true
  ha_zone                   = "${aviatrix_vpc.transit.subnets[1].region}-c"
  ha_subnet                 = aviatrix_vpc.transit.subnets[1].cidr
  ha_gw_size                = var.gw_size
}

# Transit Gateway Peering
resource "aviatrix_transit_gateway_peering" "default" {
  transit_gateway_name1 = aviatrix_transit_gateway.trans1.gw_name
  transit_gateway_name2 = aviatrix_transit_gateway.trans2.gw_name
}

# Create a GCP VPC
resource "aviatrix_vpc" "spoke1" {
  cloud_type   = 4
  account_name = var.gcp_account_name
  name         = "spoke1-vpc"

  subnets {
    name   = "subnet-1"
    region = "europe-west1"
    cidr   = "10.10.2.0/26"
  }

  subnets {
    name   = "subnet-2"
    region = "europe-west3"
    cidr   = "10.10.2.64/26"
  }
}

# Spoke Gateway - Region 1
resource "aviatrix_transit_gateway" "spoke1-eu-w-1" {
  cloud_type         = 4
  account_name       = var.gcp_account_name
  gw_name            = "spoke1-eu-w-1-gw"
  vpc_id             = aviatrix_vpc.spoke1.name
  vpc_reg            = "${aviatrix_vpc.spoke1.subnets[0].region}-b"
  gw_size            = var.gw_size
  subnet             = aviatrix_vpc.spoke1.subnets[0].cidr
  enable_active_mesh = true
  local_as_number    = 65003
  ha_zone            = "${aviatrix_vpc.spoke1.subnets[0].region}-c"
  ha_subnet          = aviatrix_vpc.spoke1.subnets[0].cidr
  ha_gw_size         = var.gw_size
}

# Spoke Gateway - Region 2
resource "aviatrix_transit_gateway" "spoke1-eu-w-3" {
  cloud_type         = 4
  account_name       = var.gcp_account_name
  gw_name            = "spoke1-eu-w-3-gw"
  vpc_id             = aviatrix_vpc.spoke1.name
  vpc_reg            = "${aviatrix_vpc.spoke1.subnets[1].region}-b"
  gw_size            = var.gw_size
  subnet             = aviatrix_vpc.spoke1.subnets[1].cidr
  enable_active_mesh = true
  local_as_number    = 65004
  ha_zone            = "${aviatrix_vpc.spoke1.subnets[1].region}-c"
  ha_subnet          = aviatrix_vpc.spoke1.subnets[1].cidr
  ha_gw_size         = var.gw_size
}

# GCP Routes
resource "google_compute_route" "spoke1-ew1b" {
  name        = "spoke1-route1"
  dest_range  = "10.0.0.0/8"
  network     = aviatrix_vpc.spoke1.name
  next_hop_ip = aviatrix_transit_gateway.spoke1-eu-w-1.private_ip
  priority    = 100
}

resource "google_compute_route" "spoke1-ew1c" {
  name        = "spoke1-route2"
  dest_range  = "10.0.0.0/8"
  network     = aviatrix_vpc.spoke1.name
  next_hop_ip = aviatrix_transit_gateway.spoke1-eu-w-1.ha_private_ip
  priority    = 100
}

resource "google_compute_route" "spoke1-ew3b" {
  name        = "spoke1-route3"
  dest_range  = "10.0.0.0/8"
  network     = aviatrix_vpc.spoke1.name
  next_hop_ip = aviatrix_transit_gateway.spoke1-eu-w-3.private_ip
  priority    = 100
}

resource "google_compute_route" "spoke1-ew3c" {
  name        = "spoke1--route4"
  dest_range  = "10.0.0.0/8"
  network     = aviatrix_vpc.spoke1.name
  next_hop_ip = aviatrix_transit_gateway.spoke1-eu-w-3.ha_private_ip
  priority    = 100
}

# Spoke Region 1 to Transit1 Connection
resource "aviatrix_transit_external_device_conn" "spoke1-eu-w-1" {
  vpc_id                    = "${aviatrix_vpc.spoke1.vpc_id}~-~freyviatrix-2020"
  connection_name           = "spoke1-euw1-to-trans"
  gw_name                   = aviatrix_transit_gateway.spoke1-eu-w-1.gw_name
  connection_type           = "bgp"
  bgp_local_as_num          = aviatrix_transit_gateway.spoke1-eu-w-1.local_as_number
  bgp_remote_as_num         = aviatrix_transit_gateway.trans1.local_as_number
  remote_gateway_ip         = aviatrix_transit_gateway.trans1.eip
  ha_enabled                = true
  backup_remote_gateway_ip  = aviatrix_transit_gateway.trans1.ha_eip
  backup_bgp_remote_as_num  = aviatrix_transit_gateway.trans1.local_as_number
  backup_pre_shared_key     = var.psk
  local_tunnel_cidr         = "169.254.1.1/30,169.254.2.1/30"
  remote_tunnel_cidr        = "169.254.1.2/30,169.254.2.2/30"
  backup_local_tunnel_cidr  = "169.254.1.5/30,169.254.2.5/30"
  backup_remote_tunnel_cidr = "169.254.1.6/30,169.254.2.6/30"
  pre_shared_key            = var.psk
  manual_bgp_advertised_cidrs = [
    aviatrix_vpc.spoke1.subnets[0].cidr
  ]
}

# Transit1 to Spoke1 - Region 1 Connection
resource "aviatrix_transit_external_device_conn" "trans-to-spoke1-euw1" {
  vpc_id                    = "${aviatrix_vpc.transit.vpc_id}~-~freyviatrix-2020"
  connection_name           = "spoke1-trans-to-euw1"
  gw_name                   = aviatrix_transit_gateway.trans1.gw_name
  connection_type           = "bgp"
  bgp_local_as_num          = aviatrix_transit_gateway.trans1.local_as_number
  bgp_remote_as_num         = aviatrix_transit_gateway.spoke1-eu-w-1.local_as_number
  remote_gateway_ip         = aviatrix_transit_gateway.spoke1-eu-w-1.eip
  ha_enabled                = true
  backup_remote_gateway_ip  = aviatrix_transit_gateway.spoke1-eu-w-1.ha_eip
  backup_bgp_remote_as_num  = aviatrix_transit_gateway.spoke1-eu-w-1.local_as_number
  backup_pre_shared_key     = var.psk
  pre_shared_key            = var.psk
  local_tunnel_cidr         = "169.254.1.2/30,169.254.2.2/30"
  remote_tunnel_cidr        = "169.254.1.1/30,169.254.2.1/30"
  backup_local_tunnel_cidr  = "169.254.1.6/30,169.254.2.6/30"
  backup_remote_tunnel_cidr = "169.254.1.5/30,169.254.2.5/30"
}

# Spoke1 Region 2 to Transit2 Connection
resource "aviatrix_transit_external_device_conn" "spoke1-eu-w-3" {
  vpc_id                    = "${aviatrix_vpc.spoke1.vpc_id}~-~freyviatrix-2020"
  connection_name           = "spoke1-euw3-to-trans"
  gw_name                   = aviatrix_transit_gateway.spoke1-eu-w-3.gw_name
  connection_type           = "bgp"
  bgp_local_as_num          = aviatrix_transit_gateway.spoke1-eu-w-3.local_as_number
  bgp_remote_as_num         = aviatrix_transit_gateway.trans2.local_as_number
  remote_gateway_ip         = aviatrix_transit_gateway.trans2.eip
  ha_enabled                = true
  backup_remote_gateway_ip  = aviatrix_transit_gateway.trans2.ha_eip
  backup_bgp_remote_as_num  = aviatrix_transit_gateway.trans2.local_as_number
  backup_pre_shared_key     = var.psk
  local_tunnel_cidr         = "169.254.1.9/30,169.254.2.9/30"
  remote_tunnel_cidr        = "169.254.1.10/30,169.254.2.10/30"
  backup_local_tunnel_cidr  = "169.254.1.13/30,169.254.2.13/30"
  backup_remote_tunnel_cidr = "169.254.1.14/30,169.254.2.14/30"
  pre_shared_key            = var.psk
  manual_bgp_advertised_cidrs = [
    aviatrix_vpc.spoke1.subnets[1].cidr
  ]
}

# Transit2 to Spoke1 - Region 2 Connection
resource "aviatrix_transit_external_device_conn" "trans-to-spoke1-euw3" {
  vpc_id                    = "${aviatrix_vpc.transit.vpc_id}~-~freyviatrix-2020"
  connection_name           = "spoke1-trans-to-euw3"
  gw_name                   = aviatrix_transit_gateway.trans2.gw_name
  connection_type           = "bgp"
  bgp_local_as_num          = aviatrix_transit_gateway.trans2.local_as_number
  bgp_remote_as_num         = aviatrix_transit_gateway.spoke1-eu-w-3.local_as_number
  remote_gateway_ip         = aviatrix_transit_gateway.spoke1-eu-w-3.eip
  ha_enabled                = true
  backup_remote_gateway_ip  = aviatrix_transit_gateway.spoke1-eu-w-3.ha_eip
  backup_bgp_remote_as_num  = aviatrix_transit_gateway.spoke1-eu-w-3.local_as_number
  backup_pre_shared_key     = var.psk
  pre_shared_key            = var.psk
  local_tunnel_cidr         = "169.254.1.10/30,169.254.2.10/30"
  remote_tunnel_cidr        = "169.254.1.9/30,169.254.2.9/30"
  backup_local_tunnel_cidr  = "169.254.1.14/30,169.254.2.14/30"
  backup_remote_tunnel_cidr = "169.254.1.13/30,169.254.2.13/30"
}

# Additional Spokes
module "spoke2" {
  source             = "terraform-aviatrix-modules/gcp-spoke/aviatrix"
  version            = "3.0.0"
  name               = "spoke2"
  account            = var.gcp_account_name
  cidr               = "10.10.3.0/26"
  region             = "europe-west1"
  transit_gw         = aviatrix_transit_gateway.trans1.gw_name
  ha_gw              = false
}

module "spoke3" {
  source             = "terraform-aviatrix-modules/gcp-spoke/aviatrix"
  version            = "3.0.0"
  name               = "spoke3"
  account            = var.gcp_account_name
  cidr               = "10.10.4.0/26"
  region             = "europe-west3"
  transit_gw         = aviatrix_transit_gateway.trans2.gw_name
  ha_gw              = false
}

# Test instances
module "gcp" {
  source = "git::https://github.com/fkhademi/terraform-gcp-instance-module.git"

  name    = "gcp1"
  region  = module.spoke2.vpc.subnets[0].region
  vpc     = module.spoke2.vpc.vpc_id
  subnet  = module.spoke2.vpc.subnets[0].name
  ssh_key = var.ssh_key
}
resource "aws_route53_record" "gcp" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "gcp1.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.gcp.vm.network_interface[0].network_ip]
}

module "gcp2" {
  source = "git::https://github.com/fkhademi/terraform-gcp-instance-module.git"

  name    = "gcp2"
  region  = module.spoke3.vpc.subnets[0].region
  vpc     = module.spoke3.vpc.vpc_id
  subnet  = module.spoke3.vpc.subnets[0].name
  ssh_key = var.ssh_key
}
resource "aws_route53_record" "gcp2" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "gcp2.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.gcp2.vm.network_interface[0].network_ip]
}

## 
module "gcp3" {
  source = "git::https://github.com/fkhademi/terraform-gcp-instance-module.git"

  name    = "gcp3"
  region  = aviatrix_vpc.spoke1.subnets[0].region
  vpc     = aviatrix_vpc.spoke1.vpc_id
  subnet  = aviatrix_vpc.spoke1.subnets[0].name
  ssh_key = var.ssh_key
}
resource "aws_route53_record" "gcp3" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "gcp3.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.gcp3.vm.network_interface[0].network_ip]
}

module "gcp4" {
  source = "git::https://github.com/fkhademi/terraform-gcp-instance-module.git"

  name    = "gcp4"
  region  = aviatrix_vpc.spoke1.subnets[1].region
  vpc     = aviatrix_vpc.spoke1.vpc_id
  subnet  = aviatrix_vpc.spoke1.subnets[1].name
  ssh_key = var.ssh_key
}
resource "aws_route53_record" "gcp4" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "gcp4.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.gcp4.vm.network_interface[0].network_ip]
}
