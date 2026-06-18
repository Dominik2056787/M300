# Dokumentation – Monitoring mit Prometheus & Grafana

---

## 1. App-Metriken in Flask

Damit Prometheus überhaupt Daten über die Anwendung sammeln kann, muss das Backend selbst Metriken bereitstellen. Dafür wurde die Library `prometheus-flask-exporter` verwendet, welche automatisch einen `/metrics` Endpoint registriert.

**Installation:**

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

Diese zwei Zeilen reichen aus, damit Flask automatisch Metriken wie Anzahl Requests, Antwortzeiten und HTTP-Statuscodes unter `/metrics` bereitstellt.

**Test:**

```bash
curl http://localhost:5000/metrics
```

<img width="736" height="455" alt="image" src="https://github.com/user-attachments/assets/60a9870d-8935-4b35-9c63-a0968b1b14e9" />


---

## 2. Helm installieren

Helm ist ein Paketmanager für Kubernetes. Damit lassen sich komplexe Anwendungen (wie Prometheus + Grafana) mit einem einzigen Befehl installieren, statt viele YAML-Files manuell zu erstellen.

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

---

## 3. Prometheus & Grafana via Helm installieren

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=NodePort \
  --set prometheus.service.type=NodePort
```

Dieser Befehl installiert mit dem Chart `kube-prometheus-stack` automatisch alle nötigen Komponenten: Prometheus, Grafana, Alertmanager, Node-Exporter und den Prometheus-Operator.

**Status prüfen:**

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


---

## 4. Service-Label korrigieren

Damit ein `ServiceMonitor` einen Service findet, muss der Service selbst ein passendes Label tragen (nicht nur sein Pod-Selector). Dies fehlte ursprünglich:

```bash
kubectl label service backend app=backend
```

**Service-Definition (`k8s/backend-deployment.yaml`), ergänzt um einen benannten Port:**

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

---

## 5. ServiceMonitor erstellen

Ein `ServiceMonitor` teilt Prometheus mit, welche Services es überwachen soll.

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

**Prüfen ob Prometheus den Service gefunden hat:**

Im Browser unter `http://34.205.190.81:9090/targets` nach `backend-monitor` suchen. Status sollte **UP** sein.

<img width="954" height="469" alt="image" src="https://github.com/user-attachments/assets/d9dfa410-888b-4c20-9e64-00845bb7e49b" />


---

## 6. Troubleshooting: Minikube Image-Caching

Ein Problem trat auf, als trotz neu gebautem Docker-Image weiterhin eine veraltete Version im Cluster lief, was zu `404 NOT FOUND` Fehlern beim Abruf von `/metrics` führte.

**Ursache:** Minikube cached Images intern nach Namen, nicht zuverlässig nach Inhalt. Ein erneutes `docker build` mit demselben Tag (`latest`) führte nicht automatisch zu einem aktualisierten Image im Cluster.

**Diagnose:**

```bash
kubectl describe pod -l app=backend | grep "Image ID"
docker images m300-backend
```

Die Image-ID im laufenden Pod stimmte nicht mit der Image-ID des frisch gebauten Docker-Images überein.

**Lösung:** Ein neuer, eindeutiger Image-Tag erzwingt, dass Minikube wirklich das neue Image lädt:

```bash
docker tag m300-backend:latest m300-backend:v2
minikube image load m300-backend:v2
```

Anschliessend wurde das Deployment auf den neuen Tag umgestellt und neu angewendet:

```bash
kubectl apply -f k8s/backend-deployment.yaml
kubectl delete pods -l app=backend
```

<img width="610" height="78" alt="image" src="https://github.com/user-attachments/assets/4ac2274f-4032-469d-933b-2122e9022879" />


---

## 7. Grafana Dashboard

Nach erfolgreicher Verbindung zwischen Backend, Prometheus und Grafana wurde ein eigenes Dashboard mit vier Panels erstellt:

| Panel | Query | Zweck |
|-------|-------|-------|
| Requests pro Sekunde | `rate(flask_http_request_total[5m])` | Zeigt den Traffic der Anwendung |
| Error Rate | `rate(flask_http_request_total{status=~"5.."}[5m])` | Zeigt Server-Fehler (5xx) |
| Response Time (avg) | `rate(flask_http_request_duration_seconds_sum[5m]) / rate(flask_http_request_duration_seconds_count[5m])` | Durchschnittliche Antwortzeit der API |
| CPU-Nutzung Backend-Pods | `sum(rate(container_cpu_usage_seconds_total{pod=~"backend-.*"}[5m])) by (pod)` | CPU-Verbrauch pro Pod |

**Grafana öffnen:**

```bash
kubectl port-forward -n monitoring service/monitoring-grafana 3000:80 --address=0.0.0.0 &
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

Zugriff über `http://34.205.190.81:3000`, Login mit `admin` und dem ausgegebenen Passwort.

<img width="954" height="462" alt="image" src="https://github.com/user-attachments/assets/a782a976-d854-4080-a20d-e6d70d2024f1" />


---

## 8. Zusammenfassung

| Komponente | Technologie | Status |
|------------|-------------|--------|
| App-Metriken | prometheus-flask-exporter | Erfolgreich |
| Paketmanager | Helm | Erfolgreich |
| Metriken-Sammlung | Prometheus (kube-prometheus-stack) | Erfolgreich |
| Service-Discovery | ServiceMonitor | Erfolgreich |
| Visualisierung | Grafana Dashboard (4 Panels) | Erfolgreich |
