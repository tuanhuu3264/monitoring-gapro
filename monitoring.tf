
resource "digitalocean_kubernetes_cluster" "primary" {
  name    = var.cluster_name
  region  = var.cluster_region
  version = var.k8s_version

  node_pool {
    name       = "${var.cluster_name}-pool"
    size       = var.node_size
    node_count = var.node_count
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
  }
  depends_on = [ digitalocean_kubernetes_cluster.primary ]
}

resource "kubernetes_namespace" "nginx" {
  metadata {
    name = var.nginx_namespace
  }
  depends_on = [ digitalocean_kubernetes_cluster.primary ]

}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = var.nginx_repository
  chart      = "ingress-nginx"   

  namespace        = kubernetes_namespace.nginx.metadata[0].name
  create_namespace = false

  values = [
    <<-EOF
    controller:
      replicaCount: 2
      service:
        type: LoadBalancer
    EOF
  ]

  depends_on = [
    kubernetes_namespace.nginx,
    digitalocean_kubernetes_cluster.primary,
  ]

  timeout = 300
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = var.bitnami_repository
  chart      = "kube-prometheus"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false

  values = [
    file("${path.module}/prometheus-values.yaml")
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    digitalocean_kubernetes_cluster.primary,
  ]

  timeout = 300
}
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
  depends_on = [ digitalocean_kubernetes_cluster.primary ]

}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = var.bitnami_repository
  chart      = "argo-cd"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false

  values = [
    file("${path.module}/argo-cd-values.yaml")
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    digitalocean_kubernetes_cluster.primary,
    helm_release.cert_manager,
    helm_release.ingress_nginx
  ]

  timeout = 300
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = var.bitnami_repository
  chart      = "grafana"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false

  values = [
    file("${path.module}/grafana-values.yaml")
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    digitalocean_kubernetes_cluster.primary,
    helm_release.cert_manager,
    helm_release.ingress_nginx
  ]

  timeout = 300
}

data "kubernetes_service" "ingress_lb" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }
  depends_on = [ helm_release.ingress_nginx ]
}

locals {
  ingress_lb_ip = lookup(
    try(data.kubernetes_service.ingress_lb.status[0].load_balancer[0].ingress[0], {}),
    "ip",
    ""
  )
}

resource "kubernetes_ingress_v1" "argocd_ingress" {
  metadata {
    name      = "argocd-ingress"
    namespace = kubernetes_namespace.argocd.metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"           = var.type_ingress
      "cert-manager.io/cluster-issuer"         = var.cluster_issuer
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
    }
  }

  spec {
    ingress_class_name = var.type_ingress

    tls {
      hosts       = ["${var.argocd_hostname}.${var.cloudflare_zone_name}"]
      secret_name = "${var.argocd_tls_key}"
    }

    rule {
      host = "${var.argocd_hostname}.${var.cloudflare_zone_name}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-argo-cd-server"
              port { number = 443 }  
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.ingress_nginx,
    helm_release.argocd,
    helm_release.cert_manager,
    kubectl_manifest.cluster_issuer_letsencrypt_prod  
  ]
}


resource "kubernetes_ingress_v1" "monitoring_ingress" {
  metadata {
    name      = "monitoring-ingress"
    namespace = kubernetes_namespace.monitoring.metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"    = var.type_ingress
      "cert-manager.io/cluster-issuer"  = var.cluster_issuer
    }
  }

  spec {
    ingress_class_name = var.type_ingress

    tls {
      hosts      = ["${var.grafana_hostname}.${var.cloudflare_zone_name}"]
      secret_name = var.grafana_tls_key
    }

    rule {
      host = "${var.grafana_hostname}.${var.cloudflare_zone_name}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "grafana"
              port { number = 3000 }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.ingress_nginx,
    helm_release.prometheus,
    helm_release.grafana,
    helm_release.cert_manager,            
    kubectl_manifest.cluster_issuer_letsencrypt_prod  
  ]
}


resource "cloudflare_record" "grafana" {
  zone_id = data.cloudflare_zone.zone.id
  name    = var.grafana_hostname                       
  value   = local.ingress_lb_ip                 
  type    = "A"
  ttl     = 300
  proxied = false
}


resource "cloudflare_record" "argocd" {
  zone_id = data.cloudflare_zone.zone.id
  name    = var.argocd_hostname                 
  value   = local.ingress_lb_ip        
  type    = "A"
  ttl     = 300
  proxied = false
}

resource "kubernetes_namespace" "keda" {
  metadata { name = "${var.keda_namespace}" }

  depends_on = [ digitalocean_kubernetes_cluster.primary ]
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = var.keda_repository
  chart      = "keda"
  namespace  = kubernetes_namespace.keda.metadata[0].name

  values = [
    file("${path.module}/keda-values.yaml")
  ]

  depends_on = [ kubernetes_namespace.keda]
}


resource "kubernetes_namespace" "cert_manager" {
  metadata { name = "cert-manager" }
  depends_on = [ digitalocean_kubernetes_cluster.primary ]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = var.bitnami_repository
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  values = [
    file("${path.module}/cert-manager-values.yaml")
  ]

  depends_on = [ kubernetes_namespace.cert_manager ]
}


resource "kubectl_manifest" "cluster_issuer_letsencrypt_prod" {
  depends_on = [helm_release.cert_manager]
  yaml_body = <<YAML
apiVersion: "cert-manager.io/v1"
kind: ClusterIssuer
metadata:
  name: ${var.cluster_issuer}

spec:
  acme:
    server: "https://acme-v02.api.letsencrypt.org/directory"
    email: ${var.email_ceo}
    privateKeySecretRef:
      name: ${var.cluster_issuer}
    solvers:
    - http01:
        ingress:
          class: ${var.type_ingress}
YAML
}


output "kubeconfig_raw" {
  description = "Nội dung kubeconfig raw của DOKS Cluster"
  value       = digitalocean_kubernetes_cluster.primary.kube_config[0].raw_config
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Endpoint (API Server) của DOKS"
  value       = digitalocean_kubernetes_cluster.primary.endpoint
}

output "ingress_external_ip" {
  description = "External IP của Ingress Controller"
  value       = local.ingress_lb_ip
  sensitive   = false
}
