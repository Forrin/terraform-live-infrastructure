locals {
  cluster_name      = "demo-cluster"
  deploy_key_name   = "demo-cluster"
  repository_name   = "operator-gitops"
  repository_branch = "main"

  flux_target_path = "clusters/demo-cluster"
  flux_sync_branch = "main"
  flux_sync_url    = "ssh://git@github.com/Forrin/operator-gitops.git"
}

# Private Key
resource "tls_private_key" "main" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Github
data "github_repository" "main" {
  name = local.repository_name
}

resource "github_repository_deploy_key" "main" {
  title      = local.deploy_key_name
  repository = local.repository_name
  key        = tls_private_key.main.public_key_openssh
  read_only  = true
}

resource "github_repository_file" "install" {
  repository = local.repository_name
  file       = data.flux_install.main.path
  content    = data.flux_install.main.content
  branch     = "main"
}

resource "github_repository_file" "sync" {
  repository = local.repository_name
  file       = data.flux_sync.main.path
  content    = data.flux_sync.main.content
  branch     = "main"
}

resource "github_repository_file" "kustomize" {
  repository = local.repository_name
  file       = data.flux_sync.main.kustomize_path
  content    = data.flux_sync.main.kustomize_content
  branch     = "main"
}

# Flux
data "flux_install" "main" {
  target_path = local.flux_target_path
}

data "flux_sync" "main" {
  target_path = local.flux_target_path
  url         = local.flux_sync_url
  branch      = local.flux_sync_branch
}

# Kubernetes
data "digitalocean_kubernetes_cluster" "this" {
  name = local.cluster_name

  depends_on = [
    module.k8s
  ]
}

provider "kubernetes" {
  host  = data.digitalocean_kubernetes_cluster.this.endpoint
  token = data.digitalocean_kubernetes_cluster.this.kube_config[0].token
  cluster_ca_certificate = base64decode(
    data.digitalocean_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  )
}

provider "kubectl" {
  load_config_file = false
  host             = data.digitalocean_kubernetes_cluster.this.endpoint
  token            = data.digitalocean_kubernetes_cluster.this.kube_config[0].token
  cluster_ca_certificate = base64decode(
    data.digitalocean_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  )
}

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

data "kubectl_file_documents" "install" {
  content = data.flux_install.main.content
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}

locals {
  install = [for v in data.kubectl_file_documents.install.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  sync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

resource "kubectl_manifest" "install" {
  for_each   = { for v in local.install : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubectl_manifest" "sync" {
  for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubernetes_secret" "main" {
  depends_on = [kubectl_manifest.install]

  metadata {
    name      = data.flux_sync.main.secret
    namespace = data.flux_sync.main.namespace
  }

  data = {
    identity       = tls_private_key.main.private_key_pem
    "identity.pub" = tls_private_key.main.public_key_pem
    known_hosts    = local.known_hosts
  }
}

# SSH
locals {
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
}
