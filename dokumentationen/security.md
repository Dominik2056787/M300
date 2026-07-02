# Security-Dokumentation – Umgang mit Zugangsdaten & Secrets

## 1. Zweck

Dieses Dokument fasst zusammen, wie im gesamten Projekt mit sensiblen Daten (API-Keys, Storage-Keys, SSH-Keys, TLS-Zertifikaten) umgegangen wurde, und begründet die jeweils gewählte Lösung. Ziel war durchgehend, dass keine Zugangsdaten im Klartext im versionierten Code (GitHub) landen.

## 2. Übersicht aller Secrets im Projekt

| Secret | Ursprünglicher Zustand | Massnahme | Ort nach Absicherung |
|---|---|---|---|
| football-data.org API Key | Hardcoded in `app.py` | Als Kubernetes Secret ausgelagert | `kubectl get secrets` (verschlüsselt im Cluster) |
| AWS Academy Credentials | – | Nur als temporäre Umgebungsvariable gesetzt, nie gespeichert | Session-Umgebungsvariablen, müssen pro Sitzung neu exportiert werden |
| SSH Private Key (AWS) | – | Nur lokal auf dem eigenen Rechner, als GitHub Secret für CI/CD hinterlegt | GitHub Repository Secret (`Fussball_dashboard`) |
| SSH Key (Azure-VM) | – | Lokal auf der EC2 generiert, Public Key an VM übergeben | `~/.ssh/azure_key` (Private Key verlässt die EC2 nie) |
| TLS-Zertifikat (self-signed) | – | Als Kubernetes TLS Secret gespeichert | `kubectl get secrets` (Typ `tls`) |
| Azure Storage Account Key | Zunächst im Klartext im Backup-Skript | In separate, nicht versionierte Datei ausgelagert | `~/.azure_backup_key`, Zugriffsrechte `chmod 600` |

## 3. Kubernetes Secrets (API Key)

Der football-data.org API Key lag ursprünglich direkt im Python-Code und war damit im öffentlichen GitHub-Repository sichtbar. Das wurde durch ein Kubernetes Secret ersetzt:

```bash
kubectl create secret generic football-api-secret \
  --from-literal=api-key=<API_KEY>
```

Der Key wird dem Backend ausschliesslich über eine Umgebungsvariable zur Laufzeit bereitgestellt:

```yaml
env:
- name: FOOTBALL_API_KEY
  valueFrom:
    secretKeyRef:
      name: football-api-secret
      key: api-key
```

```python
import os
API_KEY = os.environ.get("FOOTBALL_API_KEY", "")
```

**Begründung:** Kubernetes Secrets werden Base64-kodiert im Cluster gespeichert und sind getrennt vom Anwendungscode versioniert. Der Code selbst enthält damit keinerlei Zugangsdaten mehr, auch nicht in der Git-Historie ab dem Zeitpunkt der Umstellung.

## 4. TLS-Zertifikat als Secret

Für die HTTPS-Verschlüsselung wurde ein self-signed Zertifikat erzeugt und ebenfalls als Kubernetes Secret gespeichert statt als lose Datei im Dateisystem zu belassen:

```bash
kubectl create secret tls fussball-tls \
  --cert=/home/ubuntu/M300/k8s/tls.crt \
  --key=/home/ubuntu/M300/k8s/tls.key
```

Der Ingress-Controller referenziert das Secret direkt, sodass der private Schlüssel nicht wiederholt aus dem Dateisystem gelesen werden muss.

## 5. Azure Storage Account Key – Absicherung im Backup-Skript

### 5.1 Ausgangslage

Für den automatisierten Backup-Job (tägliches Sichern des Projektverzeichnisses nach Azure Blob Storage) wird ein Storage Account Key benötigt, um sich ohne interaktiven Login gegenüber Azure zu authentifizieren. Dieser Key gewährt vollen Zugriff (`FULL`-Berechtigung) auf den gesamten Storage Account.

Im ersten Entwurf des Backup-Skripts stand der Key direkt als Variable im Skript:

```bash
STORAGE_KEY="MY_KEY"
```

**Problem:** Das Skript liegt im Projektverzeichnis (`~/M300/scripts/`) und könnte damit versehentlich zusammen mit dem restlichen Code nach GitHub gepusht werden. Ein Storage-Key im öffentlichen Repository wäre ein ernsthaftes Sicherheitsrisiko, da damit jede Person Lese-, Schreib- und Löschzugriff auf den gesamten Storage Account hätte.

### 5.2 Massnahme: Auslagerung des Keys

Der Key wurde aus dem Skript entfernt und stattdessen in eine separate Datei ausgelagert, die **ausserhalb** des Git-versionierten Projektverzeichnisses liegt:

```bash
cat > ~/.azure_backup_key << 'EOF'
AZURE_STORAGE_KEY="<KEY>"
EOF
chmod 600 ~/.azure_backup_key
```

Der Befehl `chmod 600` setzt die Dateiberechtigungen so, dass ausschliesslich der eigene Benutzer (`ubuntu`) die Datei lesen und beschreiben darf – kein anderer Systembenutzer hat Zugriff.

Das Backup-Skript lädt den Key zur Laufzeit über `source` nach:

```bash
source /home/ubuntu/.azure_backup_key
STORAGE_KEY="$AZURE_STORAGE_KEY"
```

### 5.3 Warum diese Lösung gewählt wurde

- Die Datei `~/.azure_backup_key` liegt physisch ausserhalb von `~/M300`, also ausserhalb des Git-Repositorys – sie kann nicht versehentlich committet werden, selbst mit `git add .`
- Das Skript selbst (`backup-to-azure.sh`) kann bedenkenlos versioniert und z. B. für die Abgabe/Dokumentation gezeigt werden, ohne den echten Key preiszugeben
- `chmod 600` verhindert, dass andere lokale Benutzer auf demselben Server die Datei einsehen können
- Alternative Ansätze wie ein Azure Key Vault wären zwar noch sauberer, waren im Rahmen dieses Projekts wegen der ursprünglichen Tenant-Einschränkungen (siehe Migrationsdokumentation) nicht durchgehend verfügbar; die gewählte Lösung ist ein pragmatischer, aber wirksamer Mittelweg

### 5.4 Verifikation

```bash
cat ~/M300/scripts/backup-to-azure.sh
```

zeigt, dass im Skript nur noch die Referenz `source /home/ubuntu/.azure_backup_key` steht, kein Klartext-Key mehr enthalten ist.

## 6. .gitignore als zusätzliche Absicherung

Zusätzlich zur Auslagerung einzelner Keys wurde die `.gitignore`-Datei genutzt, um ganze Kategorien sensibler bzw. unnötig grosser Dateien konsequent von der Versionierung auszuschliessen:

```
.terraform/
*.tfstate
*.tfstate.backup
*.tfstate.*.backup
```

Terraform-State-Dateien wurden bewusst ausgeschlossen, da sie unter anderem Ressourcen-IDs und interne Konfigurationsdetails der Cloud-Umgebungen enthalten, die nicht öffentlich einsehbar sein sollten.

## 7. Zusammenfassung

| Prinzip | Umsetzung im Projekt |
|---|---|
| Trennung von Code und Zugangsdaten | Kubernetes Secrets statt hardcoded Werte |
| Keine Secrets in Versionskontrolle | `.gitignore`, externe Key-Datei mit eingeschränkten Dateirechten |
| Minimale Zugriffsrechte auf Dateisystem-Ebene | `chmod 600` für die Key-Datei |
| Verschlüsselte Übertragung | TLS-Zertifikat als Kubernetes Secret, Ingress mit SSL-Redirect |
| Temporäre statt dauerhafte Credentials, wo möglich | AWS Academy Session-Tokens nur als Umgebungsvariable, nie gespeichert |
