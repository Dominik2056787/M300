# Dokumentation – CI/CD, Kubernetes & Infrastruktur

---

## 1. Elastic IP

Eine Elastic IP ist eine statische öffentliche IP-Adresse in AWS. Im Gegensatz zu einer normalen EC2 IP ändert sie sich nicht bei einem Neustart der Instanz.

**Schritte:**
1. AWS Console → EC2 → **Elastic IPs**
2. **Allocate Elastic IP address** → **Allocate**
3. IP anklicken → **Actions** → **Associate Elastic IP address**
4. Instanz auswählen → **Associate**

<img width="960" height="419" alt="image" src="https://github.com/user-attachments/assets/d47a1094-20f3-4f1b-9716-3e53c880bf8d" />


**Resultat:** Fixe IP `34.205.190.81`

---

## 2. EC2 Instance Type & EBS Volume anpassen

Da Minikube mindestens 2GB RAM benötigt, wurde die Instanz von t2.micro auf t3.medium upgraded und das EBS Volume von 8GB auf 20GB vergrössert.

**Instance Type ändern:**
1. EC2 → Instanz stoppen
2. **Actions** → **Instance Settings** → **Change Instance Type**
3. t3.medium wählen → **Apply** → Instanz starten

**EBS Volume vergrössern:**
1. EC2 → **Volumes** → Volume anklicken
2. **Actions** → **Modify Volume** → Size auf 20GB setzen
3. Auf dem Server:
```bash
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

<img width="625" height="227" alt="image" src="https://github.com/user-attachments/assets/9d312b82-f619-4d35-8c38-58056b5e8b90" />


---

## 3. GitHub Actions CI/CD

GitHub Actions ermöglicht automatisches Deployment bei jedem Push auf den `main` Branch. Der Workflow verbindet sich per SSH auf den EC2 Server und startet die Docker Container neu.

### Secrets einrichten

Folgende Secrets wurden in GitHub hinterlegt:

| Secret Name | Inhalt |
|-------------|--------|
| `EC2_HOST` | `34.205.190.81` |
| `Fussball_dashboard` | SSH Private Key (.pem Inhalt) |

**Schritte:**
GitHub → Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

<img width="837" height="376" alt="image" src="https://github.com/user-attachments/assets/72607277-903c-4466-9d2b-3d9f99bce630" />


### Workflow Datei

Datei: `.github/workflows/deploy.yml`

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

### Ablauf

```
Developer pusht Code → GitHub Actions startet → SSH auf EC2 →
git pull → docker compose down → docker compose build → docker compose up -d
```

<img width="943" height="347" alt="image" src="https://github.com/user-attachments/assets/8f7cdc05-ad34-478a-8a98-ef178b96a901" />


---

## 4. Kubernetes mit Minikube

### Installation

```bash
# Minikube installieren
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# kubectl installieren
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Minikube starten
minikube start --driver=docker --memory=2048mb
```

<img width="360" height="59" alt="image" src="https://github.com/user-attachments/assets/4bdfcb18-ed5f-4b0f-bd93-2f669aa30d5a" />


### Deployment Files

**Backend** (`k8s/backend-deployment.yaml`):
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

**Frontend** (`k8s/frontend-deployment.yaml`):
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

### Deployments anwenden

```bash
# Images in Minikube laden
minikube image load m300-backend:latest
minikube image load m300-frontend:latest

# Deployments anwenden
kubectl apply -f ~/M300/k8s/backend-deployment.yaml
kubectl apply -f ~/M300/k8s/frontend-deployment.yaml

# Port-Forward für öffentlichen Zugriff
kubectl port-forward service/frontend 8080:8080 --address=0.0.0.0 &
kubectl port-forward service/backend 5000:5000 --address=0.0.0.0 &
```

<img width="447" height="100" alt="image" src="https://github.com/user-attachments/assets/33ca1eb6-923a-4a83-8999-31455a6ef620" />


<img width="956" height="470" alt="image" src="https://github.com/user-attachments/assets/9804b75a-6eb2-43c9-b5c8-7579fa03d541" />


---

## 5. Horizontal Pod Autoscaler (HPA)

Der HPA überwacht die CPU-Auslastung und skaliert die Pods automatisch hoch oder runter.

### Metrics Server aktivieren

```bash
minikube addons enable metrics-server
```

### HPA einrichten

```bash
kubectl autoscale deployment backend --cpu-percent=50 --min=2 --max=5
kubectl autoscale deployment frontend --cpu-percent=50 --min=2 --max=5
```

**Parameter:**
| Parameter | Wert | Bedeutung |
|-----------|------|-----------|
| `--cpu-percent` | 50% | Bei über 50% CPU → mehr Pods |
| `--min` | 2 | Minimum 2 Pods immer aktiv |
| `--max` | 5 | Maximum 5 Pods bei hoher Last |

<img width="607" height="83" alt="image" src="https://github.com/user-attachments/assets/9a09a206-400d-4071-836a-ec30dd43e1d5" />


<img width="384" height="116" alt="image" src="https://github.com/user-attachments/assets/68995ca4-748d-47da-85e0-e32246aa5d5a" />


### Wie funktioniert Auto-Scaling?

```
Wenig Traffic   → CPU niedrig → 2 Pods laufen (Minimum)
Viel Traffic    → CPU steigt über 50% → Kubernetes startet automatisch neue Pods
Traffic sinkt   → CPU sinkt → Kubernetes stoppt überschüssige Pods
```

---

## 6. Zusammenfassung

| Komponente | Technologie | Status |
|------------|-------------|--------|
| Statische IP | AWS Elastic IP | Erfolgreich |
| Automatisches Deployment | GitHub Actions | Erfolgreich |
| Container Orchestrierung | Kubernetes (Minikube) | Erfolgreich |
| Auto-Scaling | Horizontal Pod Autoscaler | Erfolgreich |
| Replicas pro Service | 2 (min) – 5 (max) | Erfolgreich |
EOF
