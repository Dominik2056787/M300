# Vollständige Migration der Applikation von AWS auf Azure

## 1. Ausgangslage und Ziel

Bisher lief die gesamte Applikation (Backend, Frontend, Kubernetes-Cluster) ausschliesslich auf einer AWS EC2 Instanz. Auf Azure existierte bisher nur ein Storage Account als Backup-Ziel. Für die volle Punktzahl im Bereich Multi-Cloud wurde die komplette Laufzeitumgebung zusätzlich auf Azure aufgebaut, sodass die Applikation eigenständig auf beiden Cloud-Anbietern läuft.

## 2. Neuer, unrestriktiver Azure Account

Der bisherige Azure-for-Students-Account über die TBZ-E-Mail-Adresse war durch eine Tenant-Policy blockiert, die die Erstellung von Netzwerk-, Storage- und Compute-Ressourcen in allen getesteten Regionen verhinderte. Es wurde ein neuer, privater Azure-for-Students-Account mit einer persönlichen E-Mail-Adresse erstellt, wodurch ein eigener Tenant ohne diese Einschränkung entstand.

```bash
az logout
az login --use-device-code
az account show --query "{SubscriptionID:id, TenantID:tenantId}" -o table
```

<img width="925" height="431" alt="image" src="https://github.com/user-attachments/assets/20346adc-f28e-4223-95b6-4456cba19361" />


## 3. Terraform Provider auf neue Subscription umstellen

In `main.tf` wurden `subscription_id` und `tenant_id` auf die neue, private Azure-Subscription angepasst. Der alte Ressourcengruppen-Eintrag wurde aus dem lokalen Terraform-State entfernt, da er sich noch auf den alten TBZ-Tenant bezog:

```bash
terraform state rm azurerm_resource_group.m300
```

## 4. Azure Provider registrieren

Bei einer neuen Azure-Subscription müssen einzelne Ressourcentypen zuerst freigeschaltet werden, bevor Terraform sie erstellen kann:

```bash
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider show --namespace Microsoft.Network --query registrationState -o tsv
az provider show --namespace Microsoft.Compute --query registrationState -o tsv
```

<img width="1275" height="82" alt="image" src="https://github.com/user-attachments/assets/683ec179-a35e-4432-8432-a94136642281" />


## 5. Netzwerk-Infrastruktur mit Terraform erstellen

Virtual Network und Subnet wurden über Terraform provisioniert:

```bash
terraform apply -target=azurerm_virtual_network.m300 -target=azurerm_subnet.m300
```

<img width="1574" height="405" alt="image" src="https://github.com/user-attachments/assets/6cdf354b-8a7b-4c0d-90f3-7b9aa1e192ee" />


## 6. SSH-Key für die Azure-VM erstellen

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_key -N ""
```

## 7. Azure VM per Terraform provisionieren

In `main.tf` wurden folgende Ressourcen ergänzt: Public IP (Static, Standard SKU), Network Security Group mit Regeln für SSH (22), Frontend (8080) und Backend (5000), Network Interface sowie die eigentliche Linux-VM (`Standard_B2s`, Ubuntu 22.04 LTS) mit dem oben erstellten SSH-Key.

```bash
terraform apply -target=azurerm_public_ip.m300_vm_ip -target=azurerm_network_security_group.m300_nsg -target=azurerm_network_interface.m300_vm_nic -target=azurerm_network_interface_security_group_association.m300_nsg_assoc -target=azurerm_linux_virtual_machine.m300_vm
```


<img width="1905" height="957" alt="image" src="https://github.com/user-attachments/assets/17e80cfd-dfbb-4a3e-8432-86895e997886" />


## 8. Öffentliche IP ermitteln und per SSH verbinden

```bash
az vm show -d -g m300-fussball-rg -n m300-fussball-vm --query publicIps -o tsv
ssh -i ~/.ssh/azure_key azureuser@<PUBLIC_IP>
```

<img width="1564" height="742" alt="image" src="https://github.com/user-attachments/assets/ecfc4216-cf18-4896-a464-0ae3c65e4600" />


## 9. Laufzeitumgebung auf der Azure-VM installieren

Dieselbe Toolchain wie auf AWS EC2 wurde neu installiert:

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


## 10. Minikube starten und Repository klonen

```bash
minikube start
cd ~
git clone https://github.com/Dominik2056787/M300.git
```

<img width="1600" height="514" alt="image" src="https://github.com/user-attachments/assets/42befbf2-85f4-4bae-be63-39fa7253dfaf" />


## 11. Docker Images bauen und in Minikube laden

```bash
cd ~/M300
docker build -t m300-backend:v2 -f src/backend/Dockerfile src/backend/
docker build -t m300-frontend:v3 -f src/frontend/Dockerfile src/frontend/
minikube image load m300-backend:v2
minikube image load m300-frontend:v3
```

## 12. Kubernetes Secret und Deployments anwenden

```bash
kubectl create secret generic football-api-secret --from-literal=api-key=<API_KEY>
kubectl apply -f ~/M300/k8s/backend-deployment.yaml
kubectl expose deployment backend --port=5000 --target-port=5000 --name=backend
kubectl apply -f ~/M300/k8s/frontend-deployment.yaml
```

<img width="1342" height="300" alt="image" src="https://github.com/user-attachments/assets/db12e0cb-eabf-4997-aabf-dead691e3b6f" />


## 13. Fehlerbehebung: Datenanzeige im Frontend

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


## 14. Port-Forwarding und Funktionstest

```bash
kubectl port-forward --address 0.0.0.0 svc/backend 5000:5000 &
kubectl port-forward --address 0.0.0.0 svc/frontend 8080:8080 &
curl "http://localhost:5000/standings?competition=PL"
curl -I http://localhost:8080
```

## 15. Ergebnis

Die Applikation läuft nun vollständig eigenständig auf Azure: Netzwerk, VM und Storage wurden über Terraform provisioniert, Backend und Frontend sind über Kubernetes (Minikube) deployed und liefern Live-Daten von football-data.org. Damit besteht die Applikation nicht nur auf AWS, sondern parallel und unabhängig auch auf Azure – die geforderte vollständige Multi-Cloud-Migration ist umgesetzt.
