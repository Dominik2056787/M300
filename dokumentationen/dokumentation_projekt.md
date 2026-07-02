# Dokumentation – M300 Fussball Dashboard

Diese Dokumentation fasst die technische Umsetzung des Projekts chronologisch zusammen: von der Containerisierung über Kubernetes, CI/CD und Monitoring bis zu Infrastructure as Code, Security-Massnahmen und der vollständigen Multi-Cloud-Migration auf Azure.

---
## Inhaltsverzeichnis

- [Teil 1 – Docker, Kubernetes, CI/CD & Autoscaling](#teil-1--docker-kubernetes-cicd--autoscaling-11062026)
- [Teil 2 – Monitoring mit Prometheus & Grafana](#teil-2--monitoring-mit-prometheus--grafana-18062026)
- [Teil 3 – Terraform & Multi-Cloud Grundlagen](#teil-3--terraform--multi-cloud-grundlagen-25062026)
- [Teil 4 – Sicherheitskonzepte](#teil-4--sicherheitskonzepte-25062026)
- [Teil 5 – Vollständige Multi-Cloud Migration AWS → Azure](#teil-5--vollständige-multi-cloud-migration-aws--azure-02072026)
- [Teil 6 – Automatisierter Backup-Job zu Azure Storage](#teil-6--automatisierter-backup-job-zu-azure-storage-02072026)


# Teil 1 – Docker, Kubernetes, CI/CD & Autoscaling (11.06.2026)

## 1.1 Elastic IP einrichten

Die öffentliche IP einer AWS EC2-Instanz wechselt normalerweise bei jedem Neustart. Für das Dashboard war das ungeeignet, da Frontend und CI/CD-Pipeline eine feste Adresse referenzieren müssen. Deshalb wurde eine **Elastic IP** eingerichtet – eine statische öffentliche IP, die dauerhaft an die Instanz gebunden bleibt.

**Schritte:**
1. AWS Console → EC2 → **Elastic IPs**
2. **Allocate Elastic IP address** → **Allocate**
3. IP anklicken → **Actions** → **Associate Elastic IP address**
4. Instanz auswählen → **Associate**

<img width="960" height="419" alt="image" src="https://github.com/user-attachments/assets/d47a1094-20f3-4f1b-9716-3e53c880bf8d" />

**Resultat:** Fixe IP `34.205.190.81`, die sich auch nach einem Neustart der Instanz nicht mehr ändert.

## 1.2 EC2 Instance Type & EBS Volume anpassen

Da Minikube mindestens 2 GB RAM benötigt und der ursprüngliche `t2.micro`-Instanztyp dafür nicht ausreichte, wurde die Instanz auf `t3.medium` (4 GB RAM) upgegradet. Gleichzeitig wurde das Speichervolumen von 8 GB auf 20 GB vergrössert, da Docker-Images und Kubernetes-Komponenten deutlich mehr Platz benötigen als ursprünglich eingeplant.

**Instance Type ändern:**
1. EC2 → Instanz stoppen
2. **Actions** → **Instance Settings** → **Change Instance Type**
3. `t3.medium` wählen → **Apply** → Instanz starten

**EBS Volume vergrössern:**
1. EC2 → **Volumes** → Volume anklicken
2. **Actions** → **Modify Volume** → Size auf 20 GB setzen
3. Auf dem Server:
```bash
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

<img width="625" height="227" alt="image" src="https://github.com/user-attachments/assets/9d312b82-f619-4d35-8c38-58056b5e8b90" />

## 1.3 Docker installieren

Docker wurde gewählt, weil es der Industriestandard für Containerisierung ist und die Applikation dadurch unabhängig vom darunterliegenden Betriebssystem lauffähig wird – eine Grundvoraussetzung für die spätere Portierung nach Azure.

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
```

Nach `usermod` muss man sich einmal aus- und wieder einloggen, damit die Docker-Gruppenrechte greifen.

## 1.4 IP-Bug im Frontend beheben

Nach dem Wechsel auf die Elastic IP war die alte, dynamische IP-Adresse noch fest im Frontend-Code hinterlegt. Das Dashboard zeigte deshalb dauerhaft „Laden…" an, da die API-Anfragen ins Leere liefen.

```bash
sed -i 's/3.81.70.127/34.205.190.81/g' ~/M300/src/frontend/index.html
```

**Erkenntnis für das Projekt:** Bei jeder IP-Änderung muss geprüft werden, ob die Adresse irgendwo hartkodiert im Code steht. Dieses Problem trat im Verlauf des Projekts nochmals auf und wurde später durch eine dynamische Ermittlung der Host-Adresse im Frontend (`window.location.hostname`) dauerhaft gelöst.

## 1.5 Dockerfiles

**Backend** (`~/M300/src/backend/Dockerfile`):
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["python3", "app.py"]
```

Ein `flask-cors`-Eintrag fehlte zunächst in der `requirements.txt` und wurde nachgetragen, da das Backend sonst wegen fehlender CORS-Freigabe vom Frontend aus nicht erreichbar war:
```bash
echo "flask-cors" >> ~/M300/src/backend/requirements.txt
```

**Frontend** (`~/M300/src/frontend/Dockerfile`):
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY . .
EXPOSE 8080
CMD ["python3", "-m", "http.server", "8080"]
```

## 1.6 Docker Images bauen & docker-compose

```bash
docker build -t fussball-backend ~/M300/src/backend
docker build -t fussball-frontend ~/M300/src/frontend
```

Statt einzelner `docker run`-Befehle wurde `docker-compose` eingesetzt, um beide Container gemeinsam als eine Einheit zu verwalten – das entspricht dem realen Aufbau der Applikation aus zwei zusammengehörigen Diensten.

`~/M300/docker-compose.yml`:
```yaml
services:
  backend:
    image: fussball-backend
    ports:
      - "5000:5000"
  frontend:
    image: fussball-frontend
    ports:
      - "8080:8080"
```

```bash
cd ~/M300
docker compose up -d
docker compose ps
```

## 1.7 GitHub Actions CI/CD

Damit jede Codeänderung automatisch auf dem Server landet, ohne dass manuell per SSH eingeloggt werden muss, wurde eine CI/CD-Pipeline mit GitHub Actions eingerichtet. Das ist für das Projekt zentral, weil es den DevOps-Grundsatz „Continuous Deployment" demonstriert: Code-Push und Produktivbetrieb sind direkt verknüpft.

**Secrets in GitHub hinterlegt** (Settings → Secrets and variables → Actions → New repository secret):

| Secret Name | Inhalt |
|-------------|--------|
| `EC2_HOST` | `34.205.190.81` |
| `Fussball_dashboard` | SSH Private Key (.pem Inhalt) |

<img width="837" height="376" alt="image" src="https://github.com/user-attachments/assets/72607277-903c-4466-9d2b-3d9f99bce630" />

**Workflow-Datei** (`.github/workflows/deploy.yml`):
```yaml
name: Deploy Fussball Dashboard

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ubuntu
          key: ${{ secrets.Fussball_dashboard }}
          script: |
            cd ~/M300
            git pull origin main
            docker compose down
            docker compose build
            docker compose up -d
```

**Ablauf:** Developer pusht Code → GitHub Actions startet → SSH auf EC2 → `git pull` → `docker compose down` → `docker compose build` → `docker compose up -d`

<img width="943" height="347" alt="image" src="https://github.com/user-attachments/assets/8f7cdc05-ad34-478a-8a98-ef178b96a901" />

## 1.8 Kubernetes mit Minikube

Docker Compose reicht für eine einfache Zwei-Container-Anwendung, bildet aber keine Selbstheilung, Skalierung oder produktionsnahe Orchestrierung ab. Für das Projekt wurde deshalb zusätzlich Kubernetes (über Minikube) eingeführt, um genau diese Fähigkeiten zu demonstrieren.

**Installation:**
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

minikube start --driver=docker --memory=2048mb
```

<img width="360" height="59" alt="image" src="https://github.com/user-attachments/assets/4bdfcb18-ed5f-4b0f-bd93-2f669aa30d5a" />

**Backend-Deployment** (`k8s/backend-deployment.yaml`):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: m300-backend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
        resources:
          requests:
            cpu: 100m
          limits:
            cpu: 200m
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
  - port: 5000
    targetPort: 5000
  type: ClusterIP
```

**Frontend-Deployment** (`k8s/frontend-deployment.yaml`):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: m300-frontend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
          limits:
            cpu: 200m
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 8080
    targetPort: 8080
  type: NodePort
```

**Anwenden:**
```bash
minikube image load m300-backend:latest
minikube image load m300-frontend:latest

kubectl apply -f ~/M300/k8s/backend-deployment.yaml
kubectl apply -f ~/M300/k8s/frontend-deployment.yaml

kubectl port-forward service/frontend 8080:8080 --address=0.0.0.0 &
kubectl port-forward service/backend 5000:5000 --address=0.0.0.0 &
```

<img width="447" height="100" alt="image" src="https://github.com/user-attachments/assets/33ca1eb6-923a-4a83-8999-31455a6ef620" />

<img width="956" height="470" alt="image" src="https://github.com/user-attachments/assets/9804b75a-6eb2-43c9-b5c8-7579fa03d541" />

## 1.9 Horizontal Pod Autoscaler (HPA)

Für das Projekt sollte gezeigt werden, dass die Applikation automatisch auf Lastspitzen reagieren kann, statt eine feste Anzahl Pods zu betreiben. Der HPA überwacht dafür die CPU-Auslastung und skaliert die Pods automatisch.

```bash
minikube addons enable metrics-server

kubectl autoscale deployment backend --cpu-percent=50 --min=2 --max=5
kubectl autoscale deployment frontend --cpu-percent=50 --min=2 --max=5
```

| Parameter | Wert | Bedeutung |
|-----------|------|-----------|
| `--cpu-percent` | 50 % | Bei über 50 % CPU → mehr Pods |
| `--min` | 2 | Minimum 2 Pods immer aktiv |
| `--max` | 5 | Maximum 5 Pods bei hoher Last |

<img width="607" height="83" alt="image" src="https://github.com/user-attachments/assets/9a09a206-400d-4071-836a-ec30dd43e1d5" />

<img width="384" height="116" alt="image" src="https://github.com/user-attachments/assets/68995ca4-748d-47da-85e0-e32246aa5d5a" />

**Zusammenfassung Teil 1:**

| Komponente | Technologie | Status |
|------------|-------------|--------|
| Statische IP | AWS Elastic IP | Erfolgreich |
| Automatisches Deployment | GitHub Actions | Erfolgreich |
| Container Orchestrierung | Kubernetes (Minikube) | Erfolgreich |
| Auto-Scaling | Horizontal Pod Autoscaler | Erfolgreich |
| Replicas pro Service | 2 (min) – 5 (max) | Erfolgreich |

---

# Teil 2 – Monitoring mit Prometheus & Grafana (18.06.2026)

Für das Projekt war es wichtig, den Betrieb der Applikation nicht nur laufen zu lassen, sondern auch messbar und überwachbar zu machen (Observability). Dafür wurde ein vollständiger Monitoring-Stack ergänzt.

## 2.1 App-Metriken in Flask

Damit Prometheus überhaupt Daten über die Anwendung sammeln kann, muss das Backend selbst Metriken bereitstellen. Dafür wurde die Library `prometheus-flask-exporter` verwendet, welche automatisch einen `/metrics`-Endpoint registriert.

```bash
cd ~/M300/src/backend
echo "prometheus-flask-exporter" >> requirements.txt
pip install prometheus-flask-exporter --break-system-packages
```

**Einbindung in `app.py`:**
```python
from flask import Flask, jsonify, request
from flask_cors import CORS
import requests

app = Flask(__name__)

from prometheus_flask_exporter import PrometheusMetrics
metrics = PrometheusMetrics(app)

CORS(app)
```

```bash
curl http://localhost:5000/metrics
```

<img width="736" height="455" alt="image" src="https://github.com/user-attachments/assets/60a9870d-8935-4b35-9c63-a0968b1b14e9" />

## 2.2 Helm installieren

Helm wurde eingesetzt, weil Prometheus und Grafana aus vielen einzelnen Kubernetes-Ressourcen bestehen, die man nicht sinnvoll von Hand pflegen kann. Helm bündelt diese als ein Paket, das mit einem Befehl installiert und aktualisiert wird.

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

## 2.3 Prometheus & Grafana via Helm installieren

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=NodePort \
  --set prometheus.service.type=NodePort
```

Dieser Befehl installiert automatisch Prometheus, Grafana, Alertmanager, Node-Exporter und den Prometheus-Operator.

```bash
kubectl get pods -n monitoring
```

| Pod | Funktion |
|-----|----------|
| `prometheus-monitoring-...` | Sammelt und speichert Metriken |
| `monitoring-grafana-...` | Visualisiert die Metriken in Dashboards |
| `alertmanager-monitoring-...` | Verwaltet Alarmierungen |
| `monitoring-kube-prometheus-operator-...` | Verwaltet ServiceMonitor-Konfigurationen |
| `monitoring-kube-state-metrics-...` | Liefert Kubernetes-Objekt-Metriken |
| `monitoring-prometheus-node-exporter-...` | Liefert Node-Metriken (CPU, RAM des Servers) |

<img width="526" height="104" alt="image" src="https://github.com/user-attachments/assets/886df14d-d2e3-47ca-8d97-844c3b7a801a" />

## 2.4 Service-Label korrigieren

Damit ein `ServiceMonitor` einen Service findet, muss der Service selbst ein passendes Label tragen, nicht nur sein Pod-Selektor. Dieses Label fehlte zunächst:

```bash
kubectl label service backend app=backend
```

Ergänzt um einen benannten Port in `k8s/backend-deployment.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
  - name: http
    port: 5000
    targetPort: 5000
  type: ClusterIP
```

## 2.5 ServiceMonitor erstellen

Ein `ServiceMonitor` teilt Prometheus mit, welche Services überwacht werden sollen – für das Projekt der Mechanismus, mit dem das Backend automatisch in die Metriken-Sammlung aufgenommen wird.

```bash
cat > ~/M300/k8s/servicemonitor.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: backend-monitor
  namespace: monitoring
  labels:
    release: monitoring
spec:
  selector:
    matchLabels:
      app: backend
  namespaceSelector:
    matchNames:
      - default
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
EOF

kubectl apply -f ~/M300/k8s/servicemonitor.yaml
```

**Wichtig:** Das Label `release: monitoring` muss exakt mit der `serviceMonitorSelector`-Konfiguration des Helm-Charts übereinstimmen, sonst ignoriert Prometheus den ServiceMonitor.

Geprüft im Browser unter `http://34.205.190.81:9090/targets` – Status von `backend-monitor` war **UP**.

<img width="954" height="469" alt="image" src="https://github.com/user-attachments/assets/d9dfa410-888b-4c20-9e64-00845bb7e49b" />

## 2.6 Troubleshooting: Minikube Image-Caching

Trotz neu gebautem Docker-Image lief weiterhin eine veraltete Version im Cluster, was zu `404 NOT FOUND`-Fehlern beim Abruf von `/metrics` führte.

**Ursache:** Minikube cached Images nach Namen, nicht zuverlässig nach Inhalt. Ein `docker build` mit demselben Tag (`latest`) führte nicht automatisch zu einem aktualisierten Image im Cluster – ein Problem, das im späteren Projektverlauf (Frontend-Redesign, Azure-Migration) erneut auftrat und stets gleich gelöst wurde.

```bash
kubectl describe pod -l app=backend | grep "Image ID"
docker images m300-backend
```

**Lösung:** Ein neuer, eindeutiger Image-Tag:
```bash
docker tag m300-backend:latest m300-backend:v2
minikube image load m300-backend:v2
kubectl apply -f k8s/backend-deployment.yaml
kubectl delete pods -l app=backend
```

<img width="610" height="78" alt="image" src="https://github.com/user-attachments/assets/4ac2274f-4032-469d-933b-2122e9022879" />

## 2.7 Grafana Dashboard

Für das Projekt wurde ein eigenes Dashboard mit vier Panels erstellt, um die Applikation aus unterschiedlichen Blickwinkeln zu überwachen (Traffic, Fehler, Performance, Ressourcenverbrauch):

| Panel | Query | Zweck |
|-------|-------|-------|
| Requests pro Sekunde | `rate(flask_http_request_total[5m])` | Zeigt den Traffic der Anwendung |
| Error Rate | `rate(flask_http_request_total{status=~"5.."}[5m])` | Zeigt Server-Fehler (5xx) |
| Response Time (avg) | `rate(flask_http_request_duration_seconds_sum[5m]) / rate(flask_http_request_duration_seconds_count[5m])` | Durchschnittliche Antwortzeit der API |
| CPU-Nutzung Backend-Pods | `sum(rate(container_cpu_usage_seconds_total{pod=~"backend-.*"}[5m])) by (pod)` | CPU-Verbrauch pro Pod |

```bash
kubectl port-forward -n monitoring service/monitoring-grafana 3000:80 --address=0.0.0.0 &
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

Zugriff über `http://34.205.190.81:3000`, Login mit `admin` und dem ausgegebenen Passwort.

<img width="954" height="462" alt="image" src="https://github.com/user-attachments/assets/a782a976-d854-4080-a20d-e6d70d2024f1" />

**Zusammenfassung Teil 2:**

| Komponente | Technologie | Status |
|------------|-------------|--------|
| App-Metriken | prometheus-flask-exporter | Erfolgreich |
| Paketmanager | Helm | Erfolgreich |
| Metriken-Sammlung | Prometheus (kube-prometheus-stack) | Erfolgreich |
| Service-Discovery | ServiceMonitor | Erfolgreich |
| Visualisierung | Grafana Dashboard (4 Panels) | Erfolgreich |

---

# Teil 3 – Terraform & Multi-Cloud Grundlagen (25.06.2026)

## 3.1 Was ist Terraform und wieso für dieses Projekt?

Terraform ist ein Open-Source Infrastructure-as-Code-Tool von HashiCorp. Statt Infrastruktur manuell in der Cloud-Konsole zu erstellen, wird sie als Code in `.tf`-Dateien beschrieben. Für das Projekt war das der Einstieg in die Multi-Cloud-Fähigkeit: dieselbe Terraform-Datei kann Ressourcen auf AWS **und** Azure gleichzeitig beschreiben, was die spätere vollständige Migration (siehe Teil 5) erst ermöglicht hat.

## 3.2 Installation

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install terraform -y
terraform -version
```

<img width="682" height="231" alt="image" src="https://github.com/user-attachments/assets/ba767305-f24e-4d75-a0ee-9b41082b937a" />

## 3.3 main.tf – Multi-Cloud Konfiguration

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

## 3.4 AWS Credentials setzen (AWS Academy)

Da AWS Academy nur temporäre Credentials ausstellt, mussten diese vor jedem `terraform plan` neu gesetzt werden:

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

## 3.5 Azure CLI Installation und Login

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login --use-device-code
```

Den angezeigten Code auf `https://login.microsoft.com/device` eingeben und mit dem TBZ-Azure-for-Students-Account einloggen.

<img width="1456" height="749" alt="image" src="https://github.com/user-attachments/assets/8cbdfdd3-2d9e-4dcc-9a1d-45fa4bce9e58" />

## 3.6 Terraform Befehle

```bash
terraform init      # Provider herunterladen und initialisieren
terraform plan      # Vorschau: Was würde Terraform erstellen?
terraform apply     # Infrastruktur wirklich erstellen
terraform destroy   # Infrastruktur wieder löschen
```

<img width="1896" height="1002" alt="image" src="https://github.com/user-attachments/assets/9214525d-06b3-4deb-a953-7d67355f2764" />

<img width="1820" height="406" alt="image" src="https://github.com/user-attachments/assets/cda3c399-76e0-4c43-9f64-366d21658a22" />

<img width="1910" height="926" alt="image" src="https://github.com/user-attachments/assets/89d534c2-840a-462f-aee1-ac8b6a8fba5f" />

## 3.7 Hinweis: Azure Student Account Einschränkungen

Der ursprüngliche Azure-for-Students-Account über die TBZ-E-Mail-Adresse hatte eingeschränkte Berechtigungen: Netzwerk-Ressourcen wie Virtual Networks waren in allen getesteten Regionen durch eine TBZ-seitige Policy gesperrt. Für dieses Projekt konnte an diesem Punkt trotzdem eine erste Multi-Cloud-Demonstration erfolgreich durchgeführt werden (AWS EC2 und Azure Resource Group via Terraform). Die vollständige Auflösung dieser Einschränkung – inklusive vollständiger Migration der Applikation auf Azure – ist in **Teil 5** dieser Dokumentation beschrieben.

## 3.8 .gitignore für Terraform

Der `.terraform/`-Ordner enthält die heruntergeladenen Provider-Binaries (AWS-Provider allein ca. 674 MB) und darf nicht ins Git-Repository gelangen, da GitHub eine harte Dateigrössenbeschränkung von 100 MB pro Datei hat. Ebenso dürfen State-Dateien nicht versioniert werden, da sie unter anderem sensible Ressourcen-IDs enthalten und sich bei jedem `apply` ändern:

```
.terraform/
*.tfstate
*.tfstate.backup
*.tfstate.*.backup
```

**Erkenntnis für das Projekt:** Diese Regel musste im späteren Verlauf (Teil 5) nochmals nachgeschärft werden, da eine automatisch erzeugte Backup-Datei mit Zeitstempel im Namen (`terraform.tfstate.<timestamp>.backup`) durch das ursprüngliche Muster nicht erfasst wurde und versehentlich committet wurde.

---

# Teil 4 – Sicherheitskonzepte (25.06.2026)

Für das Projekt war es wichtig zu zeigen, dass sensible Daten nicht im Klartext im Code liegen, dass Kommunikation innerhalb des Clusters eingeschränkt ist und dass die Applikation verschlüsselt erreichbar ist.

## 4.1 Kubernetes Secrets

Vorher war der API Key hardcoded in `app.py` und damit im GitHub-Repository öffentlich sichtbar. Secrets speichern sensitive Daten wie API Keys stattdessen verschlüsselt in Kubernetes, getrennt vom Anwendungscode.

```bash
kubectl create secret generic football-api-secret \
  --from-literal=api-key=DEIN_API_KEY
kubectl get secrets
```

<img width="1199" height="416" alt="image" src="https://github.com/user-attachments/assets/4a790560-4cdf-4e1d-aade-7aa864ebac1e" />

**Einbindung im Deployment** (`k8s/backend-deployment.yaml`):
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

```bash
kubectl apply -f k8s/backend-deployment.yaml
kubectl rollout status deployment/backend
kubectl exec -it $(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}') -- env | grep FOOTBALL
```

<img width="1889" height="93" alt="image" src="https://github.com/user-attachments/assets/b102e6b8-f584-4ba4-b74b-d7fcf141cfe5" />

## 4.2 Network Policy

Ohne Network Policy kann in Kubernetes standardmässig jeder Pod mit jedem anderen kommunizieren. Für das Projekt sollte gezeigt werden, dass nach dem Zero-Trust-Prinzip nur der Frontend-Pod auf das Backend zugreifen darf – kein anderer Pod im Cluster.

`k8s/network-policy.yaml`:
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

```bash
kubectl apply -f k8s/network-policy.yaml
kubectl get networkpolicy
```

<img width="833" height="119" alt="image" src="https://github.com/user-attachments/assets/d5581e76-d4f9-4102-8342-053738169041" />

## 4.3 HTTPS mit Ingress

Damit die Applikation nicht nur unverschlüsselt über HTTP erreichbar ist, wurde ein Ingress-Controller mit TLS-Verschlüsselung eingerichtet.

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

`k8s/ingress.yaml`:
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

```bash
kubectl apply -f k8s/ingress.yaml
kubectl get ingress
curl -k https://$(minikube ip)/ -H "Host: fussball-dashboard" -I
```

<img width="973" height="127" alt="image" src="https://github.com/user-attachments/assets/df898735-0436-4868-96bc-48b125249176" />

<img width="1300" height="221" alt="image" src="https://github.com/user-attachments/assets/70ef034d-a992-4289-99ec-0d0f393c72b0" />

**Zusammenfassung Teil 4:**

| Komponente | Technologie | Status |
|------------|-------------|--------|
| Secrets Management | Kubernetes Secret | Erfolgreich |
| Netzwerksicherheit | Network Policy | Erfolgreich |
| Transportverschlüsselung | HTTPS via nginx Ingress + self-signed TLS | Erfolgreich |

---

# Teil 5 – Vollständige Multi-Cloud Migration AWS → Azure (02.07.2026)

## 5.1 Ausgangslage und Ziel

Bisher lief die gesamte Applikation (Backend, Frontend, Kubernetes-Cluster) ausschliesslich auf einer AWS EC2 Instanz. Auf Azure existierte bisher nur eine Resource Group. Nach Rücksprache mit Herrn Rohr wurde entschieden, dass für die volle Punktzahl im Bereich Multi-Cloud die komplette Laufzeitumgebung zusätzlich auf Azure aufgebaut werden muss, sodass die Applikation eigenständig auf beiden Cloud-Anbietern läuft.

## 5.2 Neuer, unrestriktiver Azure Account

Der bisherige Azure-for-Students-Account über die TBZ-E-Mail-Adresse war durch eine Tenant-Policy blockiert, die die Erstellung von Netzwerk-, Storage- und Compute-Ressourcen in allen getesteten Regionen verhinderte (siehe Teil 3.7). Es wurde ein neuer, privater Azure-for-Students-Account mit einer persönlichen E-Mail-Adresse erstellt, wodurch ein eigener Tenant ohne diese Einschränkung entstand.

```bash
az logout
az login --use-device-code
az account show --query "{SubscriptionID:id, TenantID:tenantId}" -o table
```

<img width="925" height="431" alt="image" src="https://github.com/user-attachments/assets/20346adc-f28e-4223-95b6-4456cba19361" />

## 5.3 Terraform Provider auf neue Subscription umstellen

In `main.tf` wurden `subscription_id` und `tenant_id` auf die neue, private Azure-Subscription angepasst. Der alte Ressourcengruppen-Eintrag wurde aus dem lokalen Terraform-State entfernt, da er sich noch auf den alten TBZ-Tenant bezog:

```bash
terraform state rm azurerm_resource_group.m300
```

## 5.4 Azure Provider registrieren

Bei einer neuen Azure-Subscription müssen einzelne Ressourcentypen zuerst freigeschaltet werden, bevor Terraform sie erstellen kann – ein Schritt, der bei AWS in dieser Form nicht existiert:

```bash
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider show --namespace Microsoft.Network --query registrationState -o tsv
az provider show --namespace Microsoft.Compute --query registrationState -o tsv
```

<img width="1275" height="82" alt="image" src="https://github.com/user-attachments/assets/683ec179-a35e-4432-8432-a94136642281" />

## 5.5 Netzwerk-Infrastruktur mit Terraform erstellen

```bash
terraform apply -target=azurerm_virtual_network.m300 -target=azurerm_subnet.m300
```

<img width="1574" height="405" alt="image" src="https://github.com/user-attachments/assets/6cdf354b-8a7b-4c0d-90f3-7b9aa1e192ee" />

## 5.6 SSH-Key für die Azure-VM erstellen

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_key -N ""
```

## 5.7 Azure VM per Terraform provisionieren

In `main.tf` wurden ergänzt: Public IP (Static, Standard SKU), Network Security Group mit Regeln für SSH (22), Frontend (8080) und Backend (5000), Network Interface sowie die eigentliche Linux-VM (`Standard_B2s`, Ubuntu 22.04 LTS) mit dem oben erstellten SSH-Key.

```bash
terraform apply -target=azurerm_public_ip.m300_vm_ip -target=azurerm_network_security_group.m300_nsg -target=azurerm_network_interface.m300_vm_nic -target=azurerm_network_interface_security_group_association.m300_nsg_assoc -target=azurerm_linux_virtual_machine.m300_vm
```

<img width="1905" height="957" alt="image" src="https://github.com/user-attachments/assets/17e80cfd-dfbb-4a3e-8432-86895e997886" />

## 5.8 Öffentliche IP ermitteln und per SSH verbinden

```bash
az vm show -d -g m300-fussball-rg -n m300-fussball-vm --query publicIps -o tsv
ssh -i ~/.ssh/azure_key azureuser@<PUBLIC_IP>
```

<img width="1564" height="742" alt="image" src="https://github.com/user-attachments/assets/ecfc4216-cf18-4896-a464-0ae3c65e4600" />

## 5.9 Laufzeitumgebung auf der Azure-VM installieren

Dieselbe Toolchain wie auf AWS EC2 wurde neu installiert, um Vergleichbarkeit zwischen beiden Umgebungen sicherzustellen:

```bash
sudo apt update && sudo apt upgrade -y

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker azureuser

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

<img width="1590" height="235" alt="image" src="https://github.com/user-attachments/assets/7d0686df-5577-445f-a0d8-4e2e4237c74a" />

## 5.10 Minikube starten und Repository klonen

```bash
minikube start
cd ~
git clone https://github.com/Dominik2056787/M300.git
```

<img width="1600" height="514" alt="image" src="https://github.com/user-attachments/assets/42befbf2-85f4-4bae-be63-39fa7253dfaf" />

## 5.11 Docker Images bauen und in Minikube laden

```bash
cd ~/M300
docker build -t m300-backend:v2 -f src/backend/Dockerfile src/backend/
docker build -t m300-frontend:v3 -f src/frontend/Dockerfile src/frontend/
minikube image load m300-backend:v2
minikube image load m300-frontend:v3
```

## 5.12 Kubernetes Secret und Deployments anwenden

```bash
kubectl create secret generic football-api-secret --from-literal=api-key=<API_KEY>
kubectl apply -f ~/M300/k8s/backend-deployment.yaml
kubectl expose deployment backend --port=5000 --target-port=5000 --name=backend
kubectl apply -f ~/M300/k8s/frontend-deployment.yaml
```

<img width="1342" height="300" alt="image" src="https://github.com/user-attachments/assets/db12e0cb-eabf-4997-aabf-dead691e3b6f" />

## 5.13 Fehlerbehebung: Datenanzeige im Frontend

Nach dem ersten Deployment blieb die Tabelle im Frontend leer. Die Analyse über die Browser-Entwicklertools (Network-Tab) zeigte einen erfolgreichen Request (Status 200) mit korrekten Daten, jedoch im falschen Format – das über GitHub geklonte Backend lieferte die unveränderte, verschachtelte API-Antwort von football-data.org statt eines für das Frontend nutzbaren, flachen Arrays.

Der Endpoint `/standings` in `app.py` wurde direkt auf der Azure-VM korrigiert: Er akzeptiert nun sowohl den Parameter `competition` als auch `liga`, extrahiert die Tabelle aus der API-Antwort und wandelt sie in ein flaches Array mit `position`, `team` und `points` um.

```bash
docker build -t m300-backend:v3 -f src/backend/Dockerfile src/backend/
minikube image load m300-backend:v3
kubectl set image deployment/backend backend=m300-backend:v3
kubectl rollout status deployment/backend
```

<img width="1905" height="981" alt="image" src="https://github.com/user-attachments/assets/b249b0fa-7b53-406e-bfa0-3665d0df2868" />

<img width="1920" height="982" alt="image" src="https://github.com/user-attachments/assets/2ad7fafa-b9ce-46e0-9310-567736b34ce2" />

## 5.14 Port-Forwarding und Funktionstest

```bash
kubectl port-forward --address 0.0.0.0 svc/backend 5000:5000 &
kubectl port-forward --address 0.0.0.0 svc/frontend 8080:8080 &
curl "http://localhost:5000/standings?competition=PL"
curl -I http://localhost:8080
```

## 5.15 Ergebnis

Die Applikation läuft nun vollständig eigenständig auf Azure: Netzwerk, VM und Storage wurden über Terraform provisioniert, Backend und Frontend sind über Kubernetes (Minikube) deployed und liefern Live-Daten von football-data.org. Damit besteht die Applikation nicht nur auf AWS, sondern parallel und unabhängig auch auf Azure – die geforderte vollständige Multi-Cloud-Migration ist umgesetzt.

**Zusammenfassung Teil 5:**

| Komponente | AWS | Azure |
|---|---|---|
| Compute | EC2 (t3.medium) | VM (Standard_B2s) |
| Provisionierung | Terraform | Terraform |
| Orchestrierung | Kubernetes (Minikube) | Kubernetes (Minikube) |
| Öffentliche IP | Elastic IP (statisch) | Static Public IP |
| Deployment | Automatisiert (GitHub Actions) | Manuell |

---

# Teil 6 – Automatisierter Backup-Job zu Azure Storage (02.07.2026)

## 6.1 Ziel und Bezug zum Projekt

Bereits zu Beginn des Projekts wurde in der Kompetenzmatrix (Bereich E2 – Betrieb und Überwachung) die Anforderung „Disaster Recovery" identifiziert. Um diese Lücke zu schliessen, wurde ein automatisierter, täglicher Backup-Job eingerichtet, der das gesamte Projektverzeichnis komprimiert und in den bereits bestehenden Azure Storage Account (`m300backuphausammann`) hochlädt. Das ist gleichzeitig ein weiteres Beispiel für den Multi-Cloud-Ansatz: AWS wird für Compute genutzt, Azure für die Datensicherung.

## 6.2 Backup-Skript erstellen

Das Skript archiviert `~/M300`, schliesst dabei nicht benötigte bzw. zu grosse Ordner aus (Terraform-Provider-Cache `.terraform/`, State-Dateien, Git-Historie, Python-Cache) und lädt das Archiv per Azure CLI hoch. Danach werden nur die letzten 7 Backups behalten, ältere automatisch gelöscht.

```bash
mkdir -p ~/M300/scripts
cat > ~/M300/scripts/backup-to-azure.sh << 'EOF'
#!/bin/bash
set -e

STORAGE_ACCOUNT="m300backuphausammann"
source /home/ubuntu/.azure_backup_key
STORAGE_KEY="$AZURE_STORAGE_KEY"
CONTAINER="m300-backups"
LOG="/home/ubuntu/M300/scripts/backup.log"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE_NAME="m300-backup-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="/tmp/${ARCHIVE_NAME}"

echo "=== Backup Start: $(date) ===" >> "$LOG"

tar -czf "$ARCHIVE_PATH" \
  --exclude='.git' \
  --exclude='*.tfstate*' \
  --exclude='__pycache__' \
  --exclude='.terraform' \
  -C /home/ubuntu M300 >> "$LOG" 2>&1

echo "Archiv erstellt: $ARCHIVE_PATH ($(du -h $ARCHIVE_PATH | cut -f1))" >> "$LOG"

az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --container-name "$CONTAINER" \
  --name "$ARCHIVE_NAME" \
  --file "$ARCHIVE_PATH" >> "$LOG" 2>&1

echo "Upload abgeschlossen: $ARCHIVE_NAME" >> "$LOG"

rm -f "$ARCHIVE_PATH"

BLOBS=$(az storage blob list \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --container-name "$CONTAINER" \
  --query "[?starts_with(name, 'm300-backup-')].name" \
  -o tsv | sort)

COUNT=$(echo "$BLOBS" | wc -l)
if [ "$COUNT" -gt 7 ]; then
  TO_DELETE=$(echo "$BLOBS" | head -n $(($COUNT - 7)))
  for blob in $TO_DELETE; do
    az storage blob delete \
      --account-name "$STORAGE_ACCOUNT" \
      --account-key "$STORAGE_KEY" \
      --container-name "$CONTAINER" \
      --name "$blob" >> "$LOG" 2>&1
    echo "Altes Backup gelöscht: $blob" >> "$LOG"
  done
fi

echo "=== Backup Ende: $(date) ===" >> "$LOG"
EOF
chmod +x ~/M300/scripts/backup-to-azure.sh
```

## 6.3 Fehlerbehebung: Archivgrösse

Der erste Testlauf erzeugte ein 307 MB grosses Archiv, da der Terraform-Provider-Cache-Ordner `.terraform/` (versteckter Ordner, 1.4 GB) nicht durch die ursprünglichen Ausschlussregeln erfasst wurde. Dieser Ordner enthält reine Programmdateien, die jederzeit mit `terraform init` neu heruntergeladen werden können und daher nicht Teil eines Backups sein müssen.

```bash
du -sh ~/M300/terraform/.terraform 2>/dev/null
```

Nach Ergänzung von `--exclude='.terraform'` reduzierte sich das Archiv auf 36 KB.

## 6.4 Sicherheit: Storage Account Key ausgelagert

Der Storage Account Key wurde zunächst direkt im Skript hinterlegt. Da Skripte im Repository grundsätzlich versioniert werden könnten, wurde der Key nachträglich in eine separate, nicht versionierte Datei ausserhalb des Projektverzeichnisses ausgelagert:

```bash
cat > ~/.azure_backup_key << 'EOF'
AZURE_STORAGE_KEY="<KEY>"
EOF
chmod 600 ~/.azure_backup_key
```

Das Skript lädt den Key nun zur Laufzeit per `source` nach, sodass er nie im Klartext im versionierten Code steht (siehe `STORAGE_KEY`-Zeile in 6.2).

## 6.5 Testlauf

```bash
~/M300/scripts/backup-to-azure.sh
cat ~/M300/scripts/backup.log
```

<img width="1119" height="643" alt="image" src="https://github.com/user-attachments/assets/b9d2c57d-6b3e-4737-8db8-29d6afd040b3" />

## 6.6 Automatisierung per Cron

```bash
crontab -l 2>/dev/null > /tmp/current_cron
echo "0 2 * * * /home/ubuntu/M300/scripts/backup-to-azure.sh" >> /tmp/current_cron
crontab /tmp/current_cron
rm /tmp/current_cron
crontab -l
```

Das Backup läuft damit automatisch jeden Tag um 02:00 Uhr, ohne manuellen Eingriff.

<img width="740" height="160" alt="image" src="https://github.com/user-attachments/assets/b8060ddf-7eee-44c5-9220-95ecb54360bb" />

### Fluss diagramm Backup Konzept
<img width="624" height="565" alt="image" src="https://github.com/user-attachments/assets/3af6d9c1-8011-4926-b127-029c77533437" />
## 6.7 Verifizierung im Azure Storage

```bash
az storage blob list --account-name m300backuphausammann --account-key "<KEY>" --container-name m300-backups -o table
```
<img width="1589" height="348" alt="image" src="https://github.com/user-attachments/assets/8bacbd0e-69cd-4418-a2a7-dbd2aacce6ed" />



**Zusammenfassung Teil 6:**

| Komponente | Technologie | Status |
|------------|-------------|--------|
| Backup-Erstellung | tar-Archiv mit gezielten Ausschlüssen | Erfolgreich |
| Backup-Ziel | Azure Blob Storage | Erfolgreich |
| Automatisierung | Cron-Job (täglich 02:00 Uhr) | Erfolgreich |
| Aufbewahrung | Rotation, nur letzte 7 Backups | Erfolgreich |
| Secret-Handling | Key ausgelagert, nicht im Code | Erfolgreich |

---
