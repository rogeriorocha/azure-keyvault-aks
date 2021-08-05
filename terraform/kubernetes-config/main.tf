terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "= 2.4.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "= 2.2.0"
    }
  }
}

resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
  }
}


resource "kubernetes_deployment" "test" {
  metadata {
    name = "test"
    namespace= kubernetes_namespace.test.metadata.0.name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "test"
      }
    }
    template {
      metadata {
        labels = {
          app  = "test"
        }
      }
      spec {
        container {
          image = "nginx:1.19.4"
          name  = "nginx"

          resources {
            limits = {
              memory = "512M"
              cpu = "1"
            }
            requests = {
              memory = "256M"
              cpu = "50m"
            }
          }
        }
      }
    }
  }
}


resource helm_release nginx_ingress {
  name       = "nginx-ingress-controller"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}


resource "kubernetes_namespace" "csi-driver" {
  metadata {
    name = "csi-driver"
  }
}

/*
echo "Adding Helm repo for Secret Store CSI..."
helm repo add secrets-store-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/charts

echo "Installing Secrets Store CSI Driver using Helm..."
kubectl create ns csi-driver
helm --namespace csi-driver install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver  --set syncSecret.enabled=true
*/

resource helm_release csi-secrets-store {
  namespace =  "csi-driver" 
  name       = "csi-secrets-store"

  repository = "https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/charts"
  chart      = "secrets-store-csi-driver"

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }
}

resource "local_file" "kubeconfig" {
  content = var.kubeconfig
  filename = "${path.root}/kubeconfig"
}