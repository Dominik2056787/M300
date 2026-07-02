#!/bin/bash
set -e

LOG="/home/ubuntu/M300/scripts/startup.log"
echo "=== Start: $(date) ===" >> "$LOG"

# Warten bis Docker bereit ist
until docker info > /dev/null 2>&1; do
  echo "Warte auf Docker..." >> "$LOG"
  sleep 3
done

# Minikube starten (falls nicht schon läuft)
/usr/local/bin/minikube start >> "$LOG" 2>&1

# Warten bis alle Pods bereit sind
/usr/local/bin/kubectl wait --for=condition=Ready pods --all --timeout=180s >> "$LOG" 2>&1 || true

# Alte Port-Forwards beenden, falls noch welche laufen
pkill -f "port-forward" || true
sleep 2

# Port-Forwards neu starten (im Hintergrund, dauerhaft)
nohup /usr/local/bin/kubectl port-forward --address 0.0.0.0 svc/frontend 8080:8080 >> "$LOG" 2>&1 &
nohup /usr/local/bin/kubectl port-forward --address 0.0.0.0 svc/backend 5000:5000 >> "$LOG" 2>&1 &

echo "=== Fertig: $(date) ===" >> "$LOG"
