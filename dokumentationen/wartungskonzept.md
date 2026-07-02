# Wartungskonzept – M300 Fussball Dashboard

## 1. Zweck

Dieses Konzept beschreibt, wie das M300 Fussball Dashboard im laufenden Betrieb gewartet, aktualisiert, überwacht und im Fehlerfall wiederhergestellt wird. Es schliesst die in der Kompetenzmatrix (B1 – Integrationskonzept, Advanced-Niveau) geforderte Anforderung „Wartungskonzepte erstellen" ab und bezieht sich konkret auf die beiden produktiven Umgebungen des Projekts: AWS EC2 und Azure VM.

## 2. Betroffene Komponenten

| Komponente | AWS | Azure |
|---|---|---|
| Compute | EC2 Instanz (t3.medium) | VM (Standard_B2s) |
| Orchestrierung | Kubernetes (Minikube) | Kubernetes (Minikube) |
| Backend | Flask, 2 Pods | Flask, 2 Pods |
| Frontend | Statisches HTML/JS, 2 Pods | Statisches HTML/JS, 2 Pods |
| Monitoring | Prometheus & Grafana (Helm) | noch nicht eingerichtet |
| Infrastruktur | Terraform | Terraform |
| Backup | – | Azure Blob Storage (Cron-Job) |

## 3. Routinemässige Wartung

### 3.1 Updates einspielen

Betriebssystem-Updates werden monatlich manuell eingespielt, da die Instanzen für ein Schulprojekt nicht dauerhaft produktiv laufen:

```bash
sudo apt update && sudo apt upgrade -y
```

Nach einem Kernel-Update ist ein Neustart der Instanz nötig, damit die Änderungen wirksam werden. Der systemd-Autostart-Service (siehe 3.3) sorgt dafür, dass die Applikation danach automatisch wieder hochfährt.

### 3.2 Docker-Images aktualisieren

Bei jeder Codeänderung wird ein neuer, eindeutiger Image-Tag vergeben (z. B. `v3`, `v4`), da Minikube Images nach Tag cached und ein Wiederverwenden desselben Tags nicht zuverlässig zu einer Aktualisierung führt (siehe Dokumentation Teil 2.6):

```bash
docker build -t m300-backend:vX -f src/backend/Dockerfile src/backend/
minikube image load m300-backend:vX
kubectl set image deployment/backend backend=m300-backend:vX
kubectl rollout status deployment/backend
```

Auf AWS geschieht dies für Codeänderungen automatisch über die GitHub-Actions-Pipeline. Auf Azure ist dieser Schritt aktuell manuell auszuführen (siehe Punkt 7, offene Punkte).

### 3.3 Automatischer Start nach Neustart

Ein systemd-Service (`m300-start.service`) startet Minikube und die notwendigen Port-Forwards automatisch, sobald eine Instanz hochfährt:

```bash
sudo systemctl status m300-start.service
cat ~/M300/scripts/startup.log
```

Dieser Service ist aktuell auf AWS eingerichtet und sollte im Rahmen der Wartung auch auf die Azure-VM übertragen werden.

### 3.4 Backups

Ein täglich um 02:00 Uhr laufender Cron-Job sichert das Projektverzeichnis automatisch nach Azure Blob Storage:

```bash
crontab -l
cat ~/M300/scripts/backup.log
```

Es werden automatisch nur die letzten 7 Backups aufbewahrt, ältere werden gelöscht. Eine manuelle Kontrolle der Backups wird wöchentlich empfohlen:

```bash
az storage blob list --account-name m300backuphausammann --account-key "<KEY>" --container-name m300-backups -o table
```

## 4. Monitoring & Fehlererkennung

Auf AWS liefert Grafana (`http://34.205.190.81:3000`) eine laufende Übersicht über Requests, Fehlerrate, Antwortzeiten und CPU-Nutzung. Auffälligkeiten (z. B. dauerhaft hohe Fehlerrate oder Antwortzeiten) sind ein erstes Signal für ein Problem im Backend oder in der Anbindung an football-data.org.

**Empfohlene Prüf-Routine bei Auffälligkeiten:**

```bash
kubectl get pods
kubectl logs <pod-name> --tail=50
kubectl describe pod <pod-name>
```

Auf Azure ist aktuell kein Monitoring eingerichtet; im Fehlerfall muss dort direkt mit den obigen `kubectl`-Befehlen geprüft werden.

## 5. Vorgehen bei Störungen

| Symptom | Wahrscheinliche Ursache | Vorgehen |
|---|---|---|
| Dashboard lädt nicht | Port-Forward läuft nicht mehr | `kubectl port-forward --address 0.0.0.0 svc/frontend 8080:8080 &` neu starten |
| Tabelle bleibt leer | Backend nicht erreichbar oder falsches Datenformat | `kubectl logs` prüfen, Backend-Port-Forward neu starten, `/standings`-Endpoint direkt testen |
| Neues Design/Code erscheint nicht | Minikube Image-Cache | Neuen Image-Tag vergeben, `minikube image load`, `kubectl rollout restart` |
| Pods im Status `Error` oder `CrashLoopBackOff` | Fehlkonfiguration, fehlendes Secret, Ressourcenmangel | `kubectl describe pod`, `kubectl logs`, Secret-Vorhandensein prüfen (`kubectl get secrets`) |
| Instanz nach Neustart nicht erreichbar | Autostart-Service nicht aktiv oder fehlgeschlagen | `sudo systemctl status m300-start.service`, `cat ~/M300/scripts/startup.log` |
| Terraform-Änderungen schlagen fehl | Azure-Provider nicht registriert / abgelaufene AWS-Credentials | `az provider show --namespace <Namespace> --query registrationState`, AWS-Credentials neu exportieren |

## 6. Wiederherstellung im Ernstfall (Disaster Recovery)

Sollte eine der beiden Instanzen vollständig ausfallen oder gelöscht werden, ist die Wiederherstellung wie folgt vorgesehen:

1. Infrastruktur über Terraform neu provisionieren (`terraform apply`)
2. Aktuellstes Backup aus Azure Blob Storage herunterladen:
   ```bash
   az storage blob download --account-name m300backuphausammann --account-key "<KEY>" --container-name m300-backups --name <neuestes-backup>.tar.gz --file ~/restore.tar.gz
   tar -xzf ~/restore.tar.gz -C ~/
   ```
3. Laufzeitumgebung installieren (Docker, kubectl, Minikube, Helm)
4. Kubernetes-Manifeste anwenden, Secrets neu erstellen (Secrets sind nicht im Backup enthalten, da sensibel, und müssen manuell neu gesetzt werden)
5. Autostart-Service einrichten

## 7. Offene Punkte / nächste Wartungsschritte

- Autostart-Service auch auf der Azure-VM einrichten
- Monitoring (Prometheus/Grafana) auf Azure übertragen
- CI/CD-Pipeline auch für Azure einrichten, damit Deployments dort nicht mehr manuell erfolgen müssen
- Storage Account Key periodisch rotieren (`az storage account keys renew`), da er aktuell seit Erstellung unverändert im Einsatz ist
