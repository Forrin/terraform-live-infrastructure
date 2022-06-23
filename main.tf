module "k8s" {
  source = "github.com/Forrin/terraform-digitalocean-kubernetes?ref=v0.0.1"

  cluster_name = "demo-cluster"
  region       = "nyc1"
  ha           = false
  default_node_pool = {
    name       = "demo-node"
    size       = "s-1vcpu-2gb"
    node_count = null
    auto_scale = true
    max_nodes  = 2
    min_nodes  = 1
    labels     = { "cluster" = "demo" }
    tags       = ["demo"]
  }
}

variable "do_token" {

}

terraform {
  required_version = ">= 1.2.3"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.0"
    }

    # Providers needed for Flux
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }

    github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }

    flux = {
      source  = "fluxcd/flux"
      version = ">= 0.0.13"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}
