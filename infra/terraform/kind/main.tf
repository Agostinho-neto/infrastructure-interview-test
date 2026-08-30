resource "kind_cluster" "local" {
  name           = "infrastructure-interview"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = 30080
        host_port      = 8080
        listen_address = "127.0.0.1"
        protocol       = "TCP"
      }
    }

    node {
      role = "worker"

      labels = {
        "topology.kubernetes.io/zone" = "zone-a"
      }
    }

    node {
      role = "worker"

      labels = {
        "topology.kubernetes.io/zone" = "zone-b"
      }
    }

    node {
      role = "worker"

      labels = {
        "topology.kubernetes.io/zone" = "zone-c"
      }
    }
  }
}