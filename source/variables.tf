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

variable "terraform_version" {
  type        = string
  default     = "Terraform"
  description = "Terraform Version"
}
variable "org" {
  type        = string
  description = "tenant, which could be your organization name, e.g. aws'"
  default     = "aws"
}
variable "tenant" {
  type        = string
  description = "Account Name or unique account unique id e.g., apps or management or aws007"
  default     = ""
}
variable "environment" {
  type        = string
  default     = "preprod"
  description = "Environment area, e.g. prod or preprod "
}
variable "zone" {
  type        = string
  description = "zone, e.g. dev or qa or load or ops etc..."
  default     = ""
}
variable "attributes" {
  type        = string
  default     = ""
  description = "Additional attributes (e.g. `1`)"
}
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags (e.g. `map('BusinessUnit`,`XYZ`)"
}
#----------------------------------------------------------
// VPC
#----------------------------------------------------------
variable "create_vpc" {
  description = "Controls if VPC should be created (it affects almost all resources)"
  type        = bool
  default     = false
}
variable "enable_public_subnets" {
  description = "Enable public subnets for EKS Cluster"
  type        = bool
  default     = false
}
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for public subnets"
  type        = bool
  default     = false
}
variable "single_nat_gateway" {
  description = "Create single NAT gateway for all private subnets"
  type        = bool
  default     = true
}
variable "create_igw" {
  description = "Create internet gateway in public subnets"
  type        = bool
  default     = false
}
variable "enable_private_subnets" {
  description = "Enable private subnets for EKS Cluster"
  type        = bool
  default     = true
}

variable "vpc_id" {
  type        = string
  description = "VPC id"
  default     = ""
}

variable "private_subnet_ids" {
  description = "list of private subnets Id's for the Worker nodes"
  default     = []
}
variable "public_subnet_ids" {
  description = "list of private subnets Id's for the Worker nodes"
  default     = []
}
variable "vpc_cidr_block" {
  type        = string
  default     = ""
  description = "VPC CIDR"
}
variable "public_subnets_cidr" {
  description = "list of Public subnets for the Worker nodes"
  default     = []
}
variable "private_subnets_cidr" {
  description = "list of Private subnets for the Worker nodes"
  default     = []
}

variable "create_vpc_endpoints" {
  type        = bool
  default     = false
  description = "Create VPC endpoints for Private subnets"
}

variable "endpoint_private_access" {
  type        = bool
  default     = true
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled. Default to AWS EKS resource and it is false"
}
variable "endpoint_public_access" {
  type        = bool
  default     = true
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled. Default to AWS EKS resource and it is true"
}
variable "enable_irsa" {
  type        = bool
  default     = true
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled. Default to AWS EKS resource and it is true"
}
#----------------------------------------------------------
// EKS CONTROL PLANE
#----------------------------------------------------------
variable "kubernetes_version" {
  type        = string
  default     = "1.19"
  description = "Desired Kubernetes master version. If you do not specify a value, the latest available version is used"
}
variable "enabled_cluster_log_types" {
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  description = "A list of the desired control plane logging to enable. Possible values [`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`]"
}
variable "cluster_log_retention_period" {
  type        = number
  default     = 7
  description = "Number of days to retain cluster logs. Requires `enabled_cluster_log_types` to be set. See https://docs.aws.amazon.com/en_us/eks/latest/userguide/control-plane-logs.html."
}
variable "map_additional_aws_accounts" {
  description = "Additional AWS account numbers to add to `config-map-aws-auth` ConfigMap"
  type        = list(string)
  default     = []
}
variable "map_additional_iam_roles" {
  description = "Additional IAM roles to add to `config-map-aws-auth` ConfigMap"

  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = []
}

variable "map_additional_iam_users" {
  description = "Additional IAM users to add to `config-map-aws-auth` ConfigMap"

  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = []
}

variable "vpc_cni_addon_version" {
  type        = string
  default     = "v1.8.0-eksbuild.1"
  description = "VPC CNI Addon verison"
}
variable "coredns_addon_version" {
  type        = string
  default     = "v1.8.3-eksbuild.1"
  description = "CoreDNS Addon verison"
}
variable "kube_proxy_addon_version" {
  type        = string
  default     = "v1.20.4-eksbuild.2"
  description = "KubeProxy Addon verison"
}
variable "enable_vpc_cni_addon" {
  type = bool
  default = false
}
variable "enable_coredns_addon" {
  type = bool
  default = false
}
variable "enable_kube_proxy_addon" {
  type = bool
  default = false
}

#----------------------------------------------------------
// EKS WORKER NODES
#----------------------------------------------------------

variable "bottlerocket_ami" {
  type        = string
  default     = "ami-0326716ad575410ab"
  description = "/aws/service/bottlerocket/aws-k8s-1.19/x86_64/latest/image_id"
}
variable "bottlerocket_node_group_name" {
  type        = string
  default     = "mg-m5-bottlerocket"
  description = "AWS eks managed node group name"
}
variable "bottlerocket_disk_size" {
  type        = number
  default     = 50
  description = "Disk size in GiB for worker nodes. Defaults to 20. Terraform will only perform drift detection if a configuration value is provided"
}
variable "bottlerocket_instance_type" {
  type        = list(string)
  default     = ["m5.large"]
  description = "Set of instance types associated with the EKS Node Group"
}
variable "bottlerocket_desired_size" {
  type        = number
  default     = 3
  description = "Desired number of worker nodes"
}
variable "bottlerocket_max_size" {
  type        = number
  default     = 3
  description = "The maximum size of the AutoScaling Group"
}
variable "bottlerocket_min_size" {
  type        = number
  default     = 3
  description = "The minimum size of the AutoScaling Group"
}
variable "on_demand_node_group_name" {
  type        = string
  default     = "mg-m5-on-demand"
  description = "AWS eks managed node group name"
}
variable "on_demand_ami_type" {
  type        = string
  default     = "AL2_x86_64"
  description = "AWS eks managed worker nodes AMI type"
}
variable "on_demand_disk_size" {
  type        = number
  default     = 50
  description = "Disk size in GiB for worker nodes. Defaults to 20. Terraform will only perform drift detection if a configuration value is provided"
}
variable "on_demand_instance_type" {
  type        = list(string)
  default     = ["m5.large"]
  description = "Set of instance types associated with the EKS Node Group"
}
variable "on_demand_desired_size" {
  type        = number
  default     = 3
  description = "Desired number of worker nodes"
}
variable "on_demand_max_size" {
  type        = number
  default     = 3
  description = "The maximum size of the AutoScaling Group"
}
variable "on_demand_min_size" {
  type        = number
  default     = 3
  description = "The minimum size of the AutoScaling Group"
}
variable "spot_node_group_name" {
  type        = string
  default     = "mg-m5-spot"
  description = "AWS eks managed node group for spot"
}
variable "spot_ami_type" {
  type        = string
  default     = "AL2_x86_64"
  description = "AWS eks managed worker nodes AMI type"
}
variable "spot_instance_type" {
  type        = list(string)
  default     = ["m5.large"]
  description = "Set of instance types associated with the EKS Node Group. Defaults to [\"t3.medium\"]. Terraform will only perform drift detection if a configuration value is provided"
}
variable "spot_desired_size" {
  type        = number
  default     = 3
  description = "Desired number of worker nodes"
}
variable "spot_max_size" {
  type        = number
  default     = 3
  description = "The maximum size of the AutoScaling Group"
}
variable "spot_min_size" {
  type        = number
  default     = 1
  description = "The minimum size of the AutoScaling Group"
}
variable "kubernetes_labels" {
  type        = map(string)
  description = "Key-value mapping of Kubernetes labels. Only labels that are applied with the EKS API are managed by this argument. Other Kubernetes labels applied to the EKS Node Group will not be managed"
  default     = {}
}
variable "fargate_profile_namespace" {
  type        = string
  default     = "default"
  description = "AWS fargate profile Namespace"
}

variable "metrics_server_enable" {
  type        = bool
  default     = false
  description = "Enabling metrics server on eks cluster"
}
variable "cluster_autoscaler_enable" {
  type        = bool
  default     = false
  description = "Enabling Cluster autoscaler on eks cluster"
}
variable "traefik_ingress_controller_enable" {
  type        = bool
  default     = false
  description = "Enabling Traefik Ingress Controller on eks cluster"
}

variable "lb_ingress_controller_enable" {
  type        = bool
  default     = false
  description = "enabling LB Ingress Controller on eks cluster"
}

variable "aws_for_fluent_bit_enable" {
  type        = bool
  default     = false
  description = "Enabling aws_fluent_bit module on eks cluster"
}

variable "fargate_fluent_bit_enable" {
  type        = bool
  default     = false
  description = "Enabling fargate_fluent_bit module on eks cluster"
}

variable "ekslog_retention_in_days" {
  default     = 90
  description = "Number of days to retain log events. Default retention - 90 days."
  type        = number
}
variable "public_docker_repo" {
  type        = bool
  default     = true
  description = "public docker repo access"
}
variable "agones_enable" {
  type        = bool
  default     = false
  description = "Enabling Agones Gaming Helm Chart"
}

variable "expose_udp" {
  type        = bool
  default     = false
  description = "Enabling Agones Gaming Helm Chart"
}

variable "aws_lb_image_tag" {
default = "v2.2.1"
}

variable "aws_lb_helm_chart_version" {
default = "1.2.3"
}

variable "metric_server_image_tag" {

}
variable "metric_server_helm_chart_version" {

}

variable "cluster_autoscaler_image_tag" {
}

variable "cluster_autoscaler_helm_version" {
}