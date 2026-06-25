# Dokumentation – Terraform & Multi-Cloud

---

## 1. Was ist Terraform?

Terraform ist ein Open-Source Infrastructure as Code (IaC) Tool von HashiCorp. Infrastruktur wird nicht mehr manuell in der Cloud-Konsole erstellt sondern als Code in `.tf`-Dateien beschrieben. Der grosse Vorteil: alles ist versioniert, reproduzierbar und Cloud-übergreifend einsetzbar.

---

## 2. Installation

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install terraform -y
terraform -version
```

<img width="682" height="231" alt="image" src="https://github.com/user-attachments/assets/ba767305-f24e-4d75-a0ee-9b41082b937a" />


---

---

## 3. main.tf – Multi-Cloud Konfiguration

Die `main.tf` beschreibt gleichzeitig Ressourcen auf AWS und Azure:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
  subscription_id = "995865ce-57e4-44a8-bd4c-f5bbc723bf0f"
}

# AWS EC2 Instanz
resource "aws_instance" "fussball_server" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t3.medium"

  tags = {
    Name    = "fussball-dashboard"
    Projekt = "M300"
  }
}

# Azure Resource Group
resource "azurerm_resource_group" "m300" {
  name     = "m300-fussball-rg"
  location = "East US"
}

# Azure Virtual Network
resource "azurerm_virtual_network" "m300" {
  name                = "m300-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.m300.location
  resource_group_name = azurerm_resource_group.m300.name
}

# Azure Subnet
resource "azurerm_subnet" "m300" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.m300.name
  virtual_network_name = azurerm_virtual_network.m300.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Azure Network Interface
resource "azurerm_network_interface" "m300" {
  name                = "m300-nic"
  location            = azurerm_resource_group.m300.location
  resource_group_name = azurerm_resource_group.m300.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.m300.id
    private_ip_address_allocation = "Dynamic"
  }
}
```

---
---

## 6. AWS Credentials setzen (AWS Academy)

Da AWS Academy nur temporäre Credentials ausstellt, müssen diese vor jedem `terraform plan` neu gesetzt werden. Die Credentials findet man im AWS Academy Learner Lab unter "AWS CLI" → "Show":

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

---

## 7. Azure CLI Installation und Login

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login --use-device-code
```

Den angezeigten Code auf `https://login.microsoft.com/device` eingeben und mit dem TBZ Azure for Students Account einloggen.

<img width="1456" height="749" alt="image" src="https://github.com/user-attachments/assets/8cbdfdd3-2d9e-4dcc-9a1d-45fa4bce9e58" />


---

## 8. Terraform Befehle

```bash
terraform init      # Provider herunterladen und initialisieren
terraform plan      # Vorschau: Was würde Terraform erstellen?
terraform apply     # Infrastruktur wirklich erstellen
terraform destroy   # Infrastruktur wieder löschen
```
<img width="1896" height="1002" alt="image" src="https://github.com/user-attachments/assets/9214525d-06b3-4deb-a953-7d67355f2764" />

📷 Screenshot: `terraform apply` zeigt `aws_instance` und `azurerm_resource_group` erfolgreich erstellt
📷 Screenshot: Azure Portal → Resource Groups zeigt `m300-fussball-rg`

---

## 9. Hinweis: Azure Student Account Einschränkungen

Der Azure for Students Account über TBZ hat eingeschränkte Berechtigungen. Netzwerk-Ressourcen wie Virtual Networks waren in allen getesteten Regionen durch eine TBZ-Policy gesperrt. Die Multi-Cloud Demonstration konnte trotzdem erfolgreich durchgeführt werden: AWS EC2 und Azure Resource Group wurden via Terraform erstellt.

---

# Dokumentation – Sicherheitskonzepte (Woche 6)

---

## 1. Kubernetes Secrets

Secrets speichern sensitive Daten wie API Keys verschlüsselt in Kubernetes. Vorher war der API Key hardcoded in `app.py` und damit im GitHub Repository öffentlich sichtbar.

**Secret erstellen:**

```bash
kubectl create secret generic football-api-secret \
  --from-literal=api-key=DEIN_API_KEY
kubectl get secrets
```

📷 Screenshot: `kubectl get secrets` zeigt `football-api-secret` mit TYPE `Opaque`

**Secret im Deployment einbinden** (`k8s/backend-deployment.yaml`):

```yaml
env:
- name: FOOTBALL_API_KEY
  valueFrom:
    secretKeyRef:
      name: football-api-secret
      key: api-key
```

**In `app.py` auslesen:**

```python
import os
API_KEY = os.environ.get("FOOTBALL_API_KEY", "")
```

**Deployment anwenden und verifizieren:**

```bash
kubectl apply -f k8s/backend-deployment.yaml
kubectl rollout status deployment/backend
kubectl exec -it $(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}') -- env | grep FOOTBALL
```

📷 Screenshot: Ausgabe des letzten Befehls zeigt `FOOTBALL_API_KEY=...`

---

## 2. Network Policy

Network Policies definieren welche Pods miteinander kommunizieren dürfen. Ohne Network Policy kann jeder Pod im Cluster mit jedem anderen sprechen. Mit unserer Policy darf nur der Frontend-Pod auf das Backend zugreifen.

**`k8s/network-policy.yaml`:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 5000
```

**Anwenden:**

```bash
kubectl apply -f k8s/network-policy.yaml
kubectl get networkpolicy
```

📷 Screenshot: `kubectl get networkpolicy` zeigt `backend-network-policy`

---

## 3. HTTPS mit Ingress

**Ingress Addon aktivieren:**

```bash
minikube addons enable ingress
```

**Self-signed Zertifikat erstellen:**

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /home/ubuntu/M300/k8s/tls.key \
  -out /home/ubuntu/M300/k8s/tls.crt \
  -subj "/CN=fussball-dashboard/O=M300"
```

**Zertifikat als Kubernetes Secret speichern:**

```bash
kubectl create secret tls fussball-tls \
  --cert=/home/ubuntu/M300/k8s/tls.crt \
  --key=/home/ubuntu/M300/k8s/tls.key
```

**`k8s/ingress.yaml`:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fussball-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - fussball-dashboard
    secretName: fussball-tls
  rules:
  - host: fussball-dashboard
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 8080
      - path: /standings
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 5000
```

**Anwenden und testen:**

```bash
kubectl apply -f k8s/ingress.yaml
kubectl get ingress
curl -k https://$(minikube ip)/ -H "Host: fussball-dashboard" -I
```

📷 Screenshot: `kubectl get ingress` zeigt `fussball-ingress` mit Ports `80, 443`
📷 Screenshot: `curl` Ausgabe zeigt `HTTP/2 200`
## 5. .gitignore für Terraform

Der `.terraform/`-Ordner enthält den AWS-Provider (674MB) und darf nicht ins Git:
