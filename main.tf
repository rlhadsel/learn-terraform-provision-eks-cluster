# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
# https://dev.to/aws-builders/creating-an-eks-cluster-and-node-group-with-terraform-1lf6

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "education-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "education-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = local.cluster_name
  cluster_version = "1.27"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    # one = {
    #   name = "node-group-1"

    #   instance_types = ["t3.small"]

    #   min_size     = 1
    #   max_size     = 3
    #   desired_size = 2
    # }

    # two = {
    #   name = "node-group-2"

    #   instance_types = ["t3.small"]

    #   min_size     = 1
    #   max_size     = 2
    #   desired_size = 1
    # }

    three = {
      name = "node-group-3"

      instance_types = ["t3.small"]

      min_size     = 3
      max_size     = 3
      desired_size = 3
    }
  }
}

output "eks_oidc_info" {
  value = module.eks.oidc_provider
}

# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.20.0-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}

data "template_file" "aws_ebs_csi_driver_trust_policy_json" {
  template = file("aws_ebs_csi_driver_trust_policy.json.tpl")

  vars = {
    region       = "${var.region}"
    OIDCID       = "${module.eks.oidc_provider}"
    AWSAccountID = data.aws_caller_identity.current.account_id
  }
}

data "aws_iam_policy" "aws_ebs_csi_driver_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role" "aws_ebs_csi_driver_role" {
  name                = "AmazonEKS_EBS_CSI_DriverRole_${random_string.suffix.result}"
  assume_role_policy  = data.template_file.aws_ebs_csi_driver_trust_policy_json.rendered
  managed_policy_arns = [data.aws_iam_policy.aws_ebs_csi_driver_policy.arn]
}

# # Create an internet gateway
# resource "aws_internet_gateway" "terra_IGW" {
#   vpc_id = module.vpc.id
#   tags = {
#     name = "bastion-igw"
#   }
# }
# # Create a custom route table
# resource "aws_route_table" "terra_route_table" {
#   vpc_id = aws_vpc.terra_vpc.id
#   tags = {
#     name = "my_route_table"
#   }
# }
# # create route
# resource "aws_route" "terra_route" {
#   destination_cidr_block = "0.0.0.0/0"
#   gateway_id  = aws_internet_gateway.terra_IGW.id
#   route_table_id = aws_route_table.terra_route_table.id
# }
# # create a subnet
# resource "aws_subnet" "terra_subnet" {
#   vpc_id = aws_vpc.terra_vpc.id
#   cidr_block = "10.0.1.0/24"
#   availability_zone = var.availability_zone

#   tags = {
#     name = "my_subnet"
#   }
# }
# # associate internet gateway to the route table by using subnet
# resource "aws_route_table_association" "terra_assoc" {
#   subnet_id = aws_subnet.terra_subnet.id
#   route_table_id = aws_route_table.terra_route_table.id
# }

data "http" "my_public_ip" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  ifconfig_co_json = jsondecode(data.http.my_public_ip.body)
}

output "my_ip_addr" {
  value = local.ifconfig_co_json.ip
}

# create security group to allow ingoing ports
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "security group for bastion EC2 instance"
  vpc_id      = module.vpc.vpc_id
  ingress = [
    {
      description      = "https traffic"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["${local.ifconfig_co_json.ip}/32", "10.0.0.0/16"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "http traffic"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["${local.ifconfig_co_json.ip}/32", "10.0.0.0/16"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "ssh"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["${local.ifconfig_co_json.ip}/32", "10.0.0.0/16"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Outbound traffic rule"
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
  tags = {
    name = "allow_web"
  }
}

# # create a network interface with private ip from step 4
# resource "aws_network_interface" "terra_net_interface" {
#   subnet_id = aws_subnet.terra_subnet.id
#   security_groups = [aws_security_group.terra_SG.id]
# }
# # assign a elastic ip to the network interface created in step 7
# resource "aws_eip" "terra_eip" {
#   vpc = true
#   network_interface = aws_network_interface.terra_net_interface.id
#   associate_with_private_ip = aws_network_interface.terra_net_interface.private_ip
#   depends_on = [aws_internet_gateway.terra_IGW, aws_instance.terra_ec2]
# }

# # Create an instance profile so the aws cli commands will function in userdata scripts
# resource "aws_iam_instance_profile" "bastion_instance_profile" {
#   name = "bastion_instance_profile"
#   role = aws_iam_role.age_role.name
# }

# create an ubuntu server and install/enable apache2
resource "aws_instance" "ubuntu_bastion_ec2" {
  ami           = "ami-07b36ea9852e986ad"
  instance_type = "t3.xlarge"
  # iam_instance_profile = 
  # availability_zone           = module.vpc.azs[0]
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  disable_api_termination     = true
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0]

  user_data = data.template_file.bastion_server_setup.rendered

  tags = {
    Name = "bastion_ubuntu_server"
  }
}