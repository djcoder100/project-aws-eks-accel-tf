/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
locals {
//  tags                = merge(map("kubernetes.io/cluster/${module.eks-label.id}", "shared"), map("created-by", var.terraform_version))
//  private_subnet_tags = merge(map("kubernetes.io/cluster/${module.eks-label.id}", "shared"), map("kubernetes.io/role/internal-elb", "1"), map("created-by", var.terraform_version))
//  public_subnet_tags  = merge(map("kubernetes.io/cluster/${module.eks-label.id}", "shared"), map("kubernetes.io/role/elb", "1"), map("created-by", var.terraform_version))
  tags                = merge(tomap({"kubernetes.io/cluster/${module.eks-label.id}" = "shared"}), tomap({"created-by" = var.terraform_version}))
  private_subnet_tags = merge(tomap({"kubernetes.io/cluster/${module.eks-label.id}" = "shared"}), tomap({"kubernetes.io/role/internal-elb" = "1"}), tomap({"created-by" = var.terraform_version}))
  public_subnet_tags  = merge(tomap({"kubernetes.io/cluster/${module.eks-label.id}" = "shared"}), tomap({"kubernetes.io/role/elb" = "1"}), tomap({"created-by" = var.terraform_version}))
}


locals {
  image_repo = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com/"
}
# ---------------------------------------------------------------------------------------------------------------------
# LABELING EKS RESOURCES
# ---------------------------------------------------------------------------------------------------------------------
module "eks-label" {
  source      = "../modules/aws-resource-label"
  tenant      = var.tenant
  environment = var.environment
  zone        = var.zone
  resource    = "eks"
  tags        = local.tags
}
# ---------------------------------------------------------------------------------------------------------------------
# LABELING VPC RESOURCES
# ---------------------------------------------------------------------------------------------------------------------
module "vpc-label" {
  enabled     = var.create_vpc == true ? true : false
  source      = "../modules/aws-resource-label"
  tenant      = var.tenant
  environment = var.environment
  zone        = var.zone
  resource    = "vpc"
  tags        = local.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# VPC, SUBNETS AND ENDPOINTS DEPLOYED FOR FULLY PRIVATE EKS CLUSTERS
# ---------------------------------------------------------------------------------------------------------------------
module "vpc" {
  create_vpc          = var.create_vpc
  source              = "terraform-aws-modules/vpc/aws"
//  version             = "v2.78.0"
  version             = "v3.2.0"
  name                = module.vpc-label.id
  cidr                = var.vpc_cidr_block
  azs                 = data.aws_availability_zones.available.names
  # Private Subnets
  private_subnets     = var.enable_private_subnets ? var.private_subnets_cidr : []
  private_subnet_tags = var.enable_private_subnets ? local.private_subnet_tags : {}

  # Public Subnets
  public_subnets     = var.enable_public_subnets ? var.public_subnets_cidr : []
  public_subnet_tags = var.enable_public_subnets ? local.public_subnet_tags : {}

  enable_nat_gateway = var.enable_nat_gateway ? var.enable_nat_gateway : false
  single_nat_gateway = var.single_nat_gateway ? var.single_nat_gateway : false
  create_igw         = var.enable_public_subnets && var.create_igw ? var.create_igw : false

  enable_vpn_gateway              = false
  create_egress_only_igw          = false
  create_database_subnet_group    = false
  create_elasticache_subnet_group = false
  create_redshift_subnet_group    = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enabling Custom Domain name servers
//  enable_dhcp_options              = true
//  dhcp_options_domain_name         = "service.consul"
//  dhcp_options_domain_name_servers = ["127.0.0.1", "10.10.0.2"]

  # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  enable_flow_log                      = false
  create_flow_log_cloudwatch_log_group = false
  create_flow_log_cloudwatch_iam_role  = false
  flow_log_max_aggregation_interval    = 60

  tags = local.tags

  manage_default_security_group = true

  default_security_group_name   = "${module.vpc-label.id}-endpoint-secgrp"
  default_security_group_ingress = [
    {
      protocol    = -1
      from_port   = 0
      to_port     = 0
      cidr_blocks = var.vpc_cidr_block
  }]
  default_security_group_egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      cidr_blocks = "0.0.0.0/0"
  }]

}
################################################################################
# VPC Endpoints Module
################################################################################
module "endpoints_interface" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "v3.2.0"

  # TODO add
  create = true
  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service = "s3"
      service_type = "Gateway"
      route_table_ids = flatten([
        module.vpc.intra_route_table_ids,
        module.vpc.private_route_table_ids])
      tags = { Name = "s3-vpc-Gateway" }
    },
    /*
    dynamodb = {
      service = "dynamodb"
      service_type = "Gateway"
      route_table_ids = flatten([
        module.vpc.intra_route_table_ids,
        module.vpc.private_route_table_ids,
        module.vpc.public_route_table_ids])
      policy = data.aws_iam_policy_document.dynamodb_endpoint_policy.json
      tags = { Name = "dynamodb-vpc-endpoint" }
    },
    */
  }
}

module "vpc_endpoints_gateway" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version             = "v3.2.0"

  create = true

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [data.aws_security_group.default.id]
  subnet_ids         = module.vpc.private_subnets

  endpoints = {
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
    },
    logs = {
      service             = "logs"
      private_dns_enabled = true
    },
    autoscaling = {
      service             = "autoscaling"
      private_dns_enabled = true
    },
    sts = {
      service             = "sts"
      private_dns_enabled = true
    },
    elasticloadbalancing = {
      service             = "elasticloadbalancing"
      private_dns_enabled = true
    },
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
    },
    ec2messages = {
      service             = "ec2messages"
      private_dns_enabled = true
    },
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
    },
    kms = {
      service             = "kms"
      private_dns_enabled = true
    },
    /*    elasticfilesystem = {
          service             = "elasticfilesystem"
          private_dns_enabled = true
        },
        ssmmessages = {
          service             = "ssmmessages"
          private_dns_enabled = true
        },
        lambda = {
          service             = "lambda"
          private_dns_enabled = true
        },
        ecs = {
          service             = "ecs"
          private_dns_enabled = true
        },
        ecs_telemetry = {
          service             = "ecs-telemetry"
          private_dns_enabled = true
        },
        codedeploy = {
          service             = "codedeploy"
          private_dns_enabled = true
        },
        codedeploy_commands_secure = {
          service             = "codedeploy-commands-secure"
          private_dns_enabled = true
        },*/
  }

  tags = merge(local.tags, {
    Project  = "EKS"
    Endpoint = "true"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# RBAC DEPLOYMENT
# ---------------------------------------------------------------------------------------------------------------------
module "rbac" {
  source      = "../modules/rbac"
  tenant      = var.tenant
  environment = var.environment
  zone        = var.zone
}


# ---------------------------------------------------------------------------------------------------------------------
# EKS CONTROL PLANE AND MANAGED WORKER NODES DEPLOYED BY THIS MODULE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "eks" {
  description = "EKS Secret Encryption Key"
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  //  version                         = "14.0.0"
  version = "17.1.0"
  cluster_name = module.eks-label.id
  cluster_version = var.kubernetes_version

  vpc_id = var.create_vpc == false ? var.vpc_id : module.vpc.vpc_id

  subnets = var.create_vpc == false ? var.private_subnet_ids : module.vpc.private_subnets
  //  config_output_path              = "./kubeconfig/"
  cluster_endpoint_private_access = var.endpoint_private_access
  cluster_endpoint_public_access = var.endpoint_public_access
  enable_irsa = var.enable_irsa

  cluster_enabled_log_types = var.enabled_cluster_log_types
  workers_additional_policies = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AutoScalingFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchFullAccess",
    "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"]

  cluster_encryption_config = [
    {
      provider_key_arn = aws_kms_key.eks.arn
      resources = [
        "secrets"]
    }
  ]
  map_roles = local.common_roles
  //  map_users    = var.map_users
  //  map_accounts = var.map_accounts

  # Create security group rules to allow communication between pods on workers and pods in managed node groups.
  # Set this to true if you have AWS-Managed node groups and Self-Managed worker groups.
  # See https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1089

  //   worker_create_cluster_primary_security_group_rules = true

  tags = module.eks-label.tags

  #----------------------------------------------------------------------------------
  // Managed node groups with on-demand and spot using launch templates
  #----------------------------------------------------------------------------------
  node_groups = {
        #----------------------------------------------------------------------------------
        // SPOT WORKERS WITH PRIVATE SUBNETS
        #----------------------------------------------------------------------------------
        /*mg-m5-spot = {
          desired_capacity        = var.spot_desired_size
          min_capacity            = var.spot_min_size
          max_capacity            = var.spot_max_size
          subnets                 = var.create_vpc == false ? var.private_subnet_ids : module.vpc.private_subnets
          launch_template_id      = module.launch-templates-spot.launch_template_id
          launch_template_version = module.launch-templates-spot.launch_template_latest_version
          instance_types          = var.spot_instance_type
          capacity_type           = "SPOT"
          ami_type                = var.spot_ami_type
          #kubelet_extra_args      = "--node-labels=node.kubernetes.io/lifecycle=spot"
          k8s_labels = {
            Environment = var.environment
            Zone        = var.zone
            WorkerType  = "SPOT"
          }
          additional_tags = {
            ExtraTag = var.spot_node_group_name
            Name     = "${module.eks-label.id}-${var.spot_node_group_name}"
          }
        },*/
    #----------------------------------------------------------------------------------
    // ON DEMAND WORKERS WITH PRIVATE SUBNETS
    #----------------------------------------------------------------------------------
    mg_m5 = {
      desired_capacity = var.on_demand_desired_size
      max_capacity = var.on_demand_max_size
      min_capacity = var.on_demand_min_size

      subnets = var.create_vpc == false ? var.private_subnet_ids : module.vpc.private_subnets

      launch_template_id = module.launch-templates-on-demand.launch_template_id
      launch_template_version = module.launch-templates-on-demand.launch_template_latest_version

      instance_types = var.on_demand_instance_type
      capacity_type = "ON_DEMAND"
      ami_type = var.on_demand_ami_type

      k8s_labels = {
        Environment = var.environment
        Zone = var.zone
        WorkerType = "ON_DEMAND"
      }
      additional_tags = {
        ExtraTag = var.on_demand_node_group_name
        Name = var.on_demand_node_group_name
      }
//      taints = [
//        {
//          key = "dedicated"
//          value = "gpuGroup"
//          effect = "NO_SCHEDULE"
//        }
//      ]
    },

        #----------------------------------------------------------------------------------
        # ON DEMAND WORKERS WITH PUBLIC SUBNETS
        #----------------------------------------------------------------------------------
        /*mg-m5-on-demand-public = {
          desired_capacity        = var.on_demand_desired_size
          max_capacity            = var.on_demand_max_size
          min_capacity            = var.on_demand_min_size
          subnets                 = var.create_vpc == false ? var.public_subnet_ids : module.vpc.public_subnets
          launch_template_id      = module.public-launch-templates-on-demand.launch_template_id
          launch_template_version = module.public-launch-templates-on-demand.launch_template_latest_version
          instance_types          = var.on_demand_instance_type
          capacity_type           = "ON_DEMAND"
          ami_type                = var.on_demand_ami_type

          k8s_labels = {
            Environment = var.environment
            Zone        = var.zone
            WorkerType  = "ON_DEMAND"
          }
          additional_tags = {
            ExtraTag = var.on_demand_node_group_name
            Name     = "${module.eks-label.id}-${var.on_demand_node_group_name}"
          }
        },*/

        #----------------------------------------------------------------------------------
        # BOTTLEROCKET
        #----------------------------------------------------------------------------------
        /*brkt = {
          desired_capacity        = var.bottlerocket_desired_size
          max_capacity            = var.bottlerocket_max_size
          min_capacity            = var.bottlerocket_min_size
          subnets                 = var.create_vpc == false ? var.private_subnet_ids : module.vpc.private_subnets
          launch_template_id      = module.launch-templates-bottlerocket.launch_template_id
          launch_template_version = module.launch-templates-bottlerocket.launch_template_latest_version
          instance_types          = var.bottlerocket_instance_type
          capacity_type           = "ON_DEMAND"
          //      ami_type                = var.on_demand_ami_type

          k8s_labels = {
            Environment = var.environment
            Zone        = var.zone
            OS          = "bottlerocket"
            WorkerType  = "ON_DEMAND_BOTTLEROCKET"
          }
          additional_tags = {
            ExtraTag = var.bottlerocket_node_group_name
            Name     = "${module.eks-label.id}-${var.bottlerocket_node_group_name}"
          }
        },*/
      #----------------------------------------------------------------------------------
      #   Using Launch Templates With Both Spot and On Demand   - self managed spot and on-demand
      #----------------------------------------------------------------------------------
      /*
        worker_groups_launch_template = [{
          name                    = "mixed-demand-spot"
          override_instance_types = ["m5.large", "m5a.large", "m4.large"]
          root_encrypted          = true
          root_volume_size        = 50

          asg_min_size                             = 2
          asg_desired_capacity                     = 2
          on_demand_base_capacity                  = 3
          on_demand_percentage_above_base_capacity = 25
          asg_max_size                             = 20
          spot_instance_pools                      = 3

          kubelet_extra_args = "--node-labels=node.kubernetes.io/lifecycle=`curl -s http://169.254.169.254/latest/meta-data/instance-life-cycle`"
        }]
        */
  }

  #----------------------------------------------------------------------------------
  # Fargate profile for default namespace
  #----------------------------------------------------------------------------------

  /*fargate_profiles = {
    fg-ns-default = {
      name = var.fargate_profile_namespace

      subnets   = var.create_vpc == false ? var.private_subnet_ids : module.vpc.private_subnets

      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        },
        {
          namespace = var.fargate_profile_namespace
          labels = {
            WorkerType = "fargate"
          }
        }
      ]
      tags = {
        Environment = var.environment
        Zone        = var.zone
        worker_type = "fargate"
      }
    }
  }*/
}

# ---------------------------------------------------------------------------------------------------------------------
# EKS WORKER NODE LAUNCH TEMPLATES
# ---------------------------------------------------------------------------------------------------------------------

module "public-launch-templates-on-demand" {
  source                   = "../modules/launch-templates"
  cluster_name             = module.eks.cluster_id
  volume_size              = "50"
  worker_security_group_id = module.eks.worker_security_group_id
  node_group_name          = var.on_demand_node_group_name
  tags                     = module.eks-label.tags
  cluster_auth_base64      = module.eks.cluster_certificate_authority_data
  cluster_endpoint         = module.eks.cluster_endpoint
  public_launch_template   = true
  //  instance_type            = var.instance_type
}

module "launch-templates-on-demand" {
  source                   = "../modules/launch-templates"
  cluster_name             = module.eks.cluster_id
  volume_size              = "50"
  worker_security_group_id = module.eks.worker_security_group_id
  node_group_name          = var.on_demand_node_group_name
  tags                     = module.eks-label.tags
  cluster_auth_base64      = module.eks.cluster_certificate_authority_data
  cluster_endpoint         = module.eks.cluster_endpoint
  //  instance_type            = var.instance_type
}

module "launch-templates-spot" {
  source                   = "../modules/launch-templates"
  cluster_name             = module.eks.cluster_id
  volume_size              = "50"
  worker_security_group_id = module.eks.worker_security_group_id
  node_group_name          = var.spot_node_group_name
  tags                     = module.eks-label.tags
  cluster_auth_base64      = module.eks.cluster_certificate_authority_data
  cluster_endpoint         = module.eks.cluster_endpoint
  //  instance_type            = var.instance_type
}

module "launch-templates-bottlerocket" {
  source                   = "../modules/launch-templates"
  cluster_name             = module.eks.cluster_id
  volume_size              = "50"
  worker_security_group_id = module.eks.worker_security_group_id
  node_group_name          = var.bottlerocket_node_group_name
  tags                     = module.eks-label.tags
  bottlerocket_ami         = var.bottlerocket_ami
  self_managed             = true
  cluster_auth_base64      = module.eks.cluster_certificate_authority_data
  cluster_endpoint         = module.eks.cluster_endpoint
  //  instance_type            = var.instance_type
}

# ---------------------------------------------------------------------------------------------------------------------
# AWS EKS Add-ons (VPC CNI, CoreDNS, KubeProxy )
# ---------------------------------------------------------------------------------------------------------------------
module "aws-eks-addon" {
  source = "../modules/aws-eks-addon"
  cluster_name = module.eks.cluster_id
  enable_vpc_cni_addon = var.enable_vpc_cni_addon
  vpc_cni_addon_version = var.vpc_cni_addon_version

  enable_coredns_addon = var.enable_coredns_addon
  coredns_addon_version = var.coredns_addon_version

  enable_kube_proxy_addon = var.enable_kube_proxy_addon
  kube_proxy_addon_version = var.kube_proxy_addon_version
  tags = module.eks-label.tags
}
# ---------------------------------------------------------------------------------------------------------------------
# IAM Module
# ---------------------------------------------------------------------------------------------------------------------
module "iam" {
  source      = "../modules/iam"
  environment = var.environment
  tenant      = var.tenant
  zone        = var.zone
  account_id  = data.aws_caller_identity.current.account_id
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 BUCKET MODULE
# ---------------------------------------------------------------------------------------------------------------------

module "s3" {
  source         = "../modules/s3"
  s3_bucket_name = "${var.tenant}-${var.environment}-${var.zone}-elb-accesslogs-${data.aws_caller_identity.current.account_id}"
  account_id     = data.aws_caller_identity.current.account_id
}

# ---------------------------------------------------------------------------------------------------------------------
# Invoking Helm Module
# ---------------------------------------------------------------------------------------------------------------------
module "helm" {
  source                            = "../helm"
  eks_cluster_id                    = module.eks.cluster_id
  public_docker_repo                = var.public_docker_repo
  image_repo_url                    = local.image_repo

  # ------- Cluster Autoscaler
  cluster_autoscaler_enable         = var.cluster_autoscaler_enable
  cluster_autoscaler_image_tag = var.cluster_autoscaler_image_tag
  cluster_autoscaler_helm_version = var.cluster_autoscaler_helm_version

  # ------- Metric Server
  metrics_server_enable             = var.metrics_server_enable
  metric_server_image_tag           = var.metric_server_image_tag
  metric_server_helm_chart_version  = var.metric_server_helm_chart_version

  # ------- Traefik Ingress Controller
  traefik_ingress_controller_enable = var.traefik_ingress_controller_enable
  s3_nlb_logs                       = module.s3.s3_bucket_name

  # ------- AWS LB Controller
  lb_ingress_controller_enable      = var.lb_ingress_controller_enable
  aws_lb_image_tag = var.aws_lb_image_tag
  aws_lb_helm_chart_version = var.aws_lb_helm_chart_version
  eks_oidc_issuer_url               = module.eks.cluster_oidc_issuer_url
  eks_oidc_provider_arn             = module.eks.oidc_provider_arn

  # ------- AWS Fluent bit for Node Groups
  aws_for_fluent_bit_enable         = var.aws_for_fluent_bit_enable
  ekslog_retention_in_days          = var.ekslog_retention_in_days

  # ------- AWS Fluentbit for Fargate
  fargate_fluent_bit_enable         = var.fargate_fluent_bit_enable
  fargate_iam_role                  = module.eks.fargate_iam_role_name

  # ------- Agones Gaming Module ---------
  agones_enable                     = var.agones_enable
  expose_udp                        = var.expose_udp
  eks_security_group_id             = module.eks.worker_security_group_id

}