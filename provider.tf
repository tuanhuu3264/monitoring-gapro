terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
     kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.19"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
     kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
  required_version = ">= 1.0"
}

provider "digitalocean" {
  token = var.do_token
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}



data "cloudflare_zone" "zone" {
  name = var.cloudflare_zone_name
}


provider "kubernetes" {
  host = digitalocean_kubernetes_cluster.primary.endpoint
  token = digitalocean_kubernetes_cluster.primary.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host                   = digitalocean_kubernetes_cluster.primary.endpoint
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate)
    token                  = digitalocean_kubernetes_cluster.primary.kube_config[0].token
    
  }
}
provider "kubectl" {
  host                   = digitalocean_kubernetes_cluster.primary.endpoint  # Kubernetes API endpoint from the EKS cluster data
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate)  # Decodes the certificate authority from the cluster data
  token                  = digitalocean_kubernetes_cluster.primary.kube_config[0].token  # Authentication token for Kubernetes API access
  load_config_file       = false
}