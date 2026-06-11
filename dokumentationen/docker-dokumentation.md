# Docker Setup – Fussball Dashboard

**Datum:** 11. Juni 2026  
**Projekt:** M300 – Cloud-natives Fussball Dashboard  
**Server:** AWS EC2 Ubuntu, IP: 34.205.190.81

---

## 1. Elastic IP einrichten

Da die öffentliche IP von EC2 bei jedem Neustart wechselt, wurde eine statische Elastic IP eingerichtet.

**Schritte:**
1. AWS Console → EC2 → **Elastic IPs**
2. **Allocate Elastic IP address** → **Allocate**
3. IP anklicken → **Actions** → **Associate Elastic IP address**
4. Instanz auswählen → **Associate**

**Resultat:** Fixe IP `34.205.190.81` — ändert sich nicht mehr, auch nach Neustart.

---

## 2. IP-Bug im Frontend beheben

Nach dem IP-Wechsel war die alte IP `3.81.70.127` noch im Frontend hardcodiert. Das Dashboard zeigte nur „Laden..." an.

**Lösung:**
```bash
sed -i 's/3.81.70.127/34.205.190.81/g' ~/M300/src/frontend/index.html
```

**Erkenntnis:** Bei IP-Änderungen immer prüfen ob die IP im Frontend hardcodiert ist.

---

## 3. Docker installieren

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
```

Nach `usermod` ausloggen und neu einloggen, damit die Docker-Gruppe aktiv wird.

**Version prüfen:**
```bash
docker --version
# Docker version 29.1.3, build 29.1.3-0ubuntu4.1
```

---

## 4. Dockerfile – Backend

Datei: `~/M300/src/backend/Dockerfile`

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["python3", "app.py"]
```

**Problem:** Beim ersten Build fehlte `flask-cors` in der `requirements.txt`.  
**Lösung:**
```bash
echo "flask-cors" >> ~/M300/src/backend/requirements.txt
```

---

## 5. Dockerfile – Frontend

Datei: `~/M300/src/frontend/Dockerfile`

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY . .
EXPOSE 8080
CMD ["python3", "-m", "http.server", "8080"]
```

---

## 6. Docker Images bauen

```bash
docker build -t fussball-backend ~/M300/src/backend
docker build -t fussball-frontend ~/M300/src/frontend
```

---

## 7. Docker Compose einrichten

Statt zwei separate `docker run` Befehle wird docker-compose verwendet.

Datei: `~/M300/docker-compose.yml`

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

**Container starten:**
```bash
cd ~/M300
docker compose up -d
```

**Container stoppen:**
```bash
docker compose down
```

**Status prüfen:**
```bash
docker compose ps
```

---

## 8. Resultat

| Service  | URL                          | Status |
|----------|------------------------------|--------|
| Frontend | http://34.205.190.81:8080    | Up  |
| Backend  | http://34.205.190.81:5000    | Up  |

Das Fussball Dashboard läuft vollständig in Docker Containern und ist über die fixe Elastic IP erreichbar.

---

## Probleme & Lösungen

| Problem | Ursache | Lösung |
|--------|---------|--------|
| Dashboard zeigt „Laden..." | Alte IP hardcodiert im Frontend | IP mit `sed` ersetzt |
| Backend Container crasht | `flask-cors` fehlte in requirements.txt | Modul nachgetragen, Image neu gebaut |
| `docker-compose` not found | Neuere Docker-Version hat compose eingebaut | `docker compose` (ohne Bindestrich) verwenden |
