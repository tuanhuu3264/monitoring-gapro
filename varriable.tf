variable "do_token" {
  description = "DigitalOcean API Token (Read/Write) để tạo cluster và deploy ứng dụng"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Tên DOKS cluster sẽ tạo mới trên DigitalOcean"
  type        = string
}

variable "cluster_region" {
  description = "Region tạo cluster (ví dụ sgp1, nyc1, fra1…) trên DO"
  type        = string
}

variable "k8s_version" {
  description = "Phiên bản Kubernetes trên DOKS (ví dụ 1.32.2-do.1)"
  type        = string
}

variable "node_size" {
  description = "Droplet plan cho nodes (ví dụ s-2vcpu-2gb, s-2vcpu-4gb)"
  type        = string
}

variable "node_count" {
  description = "Số lượng nodes trong pool"
  type        = number
}

variable "monitoring_namespace" {
  description = "Namespace để deploy Prometheus & Grafana"
  type        = string
}

variable "nginx_namespace" {
  description = "Namespace để deploy Ingress-NGINX Controller"
  type        = string
  default     = "nginx"
}

variable "argocd_namespace" {
  description = "Namespace deploy argocd"
  type        = string
}
variable "keda_namespace" {
  description = "Namespace deploy keda"
  type        = string
}

variable "cer_manager_namespace" {
  description = "Namespace deploy cert manager"
  type        = string
}

variable "bitnami_repository" {
  description = "Repository Bitnami"
  type        = string
}


variable "keda_repository" {
  description = "Repository keda"
  type        = string
}


variable "nginx_repository" {
  description = "Repository nginx"
  type        = string
}

variable "cluster_issuer" {
  description = "ingress cluster issuer"
  type        = string
}
variable "type_ingress" {
  description = "type ingress"
  type        = string
}

variable "grafana_tls_key"  {
  description = "tls key Grafana"
  type        = string
}

variable "argocd_tls_key"  {
  description = "tls key Bitnami Grafana"
  type        = string
}

variable "cloudflare_token" {
  description = "Cloudflare Token (Read/Write)"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_name" {
  description = "Tên zone trên Cloudflare, ví dụ: htt08.org"
  type        = string
}

variable "email_ceo" {
    description = "email nguoi cai dat"
  type        = string
}
variable "grafana_hostname" {
  description = "grafana hostname"
  type        = string
}
variable "argocd_hostname" {
  description = "grafana hostname"
  type        = string
}