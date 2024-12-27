resource "digitalocean_kubernetes_cluster" "doks-drewpy" {
  name   = "doks-drewpy"
  region = "nyc1"
  # Grab the latest version slug from `doctl kubernetes options versions`
  version = "1.31.1-do.5"

  node_pool {
    name       = "worker-pool"
    size       = "s-1vcpu-2gb"
    node_count = 2

    taint {
      key    = "workloadKind"
      value  = "application"
      effect = "NoSchedule"
    }
  }
}