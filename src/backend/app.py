from flask import Flask, jsonify, request
from flask_cors import CORS
from prometheus_flask_exporter import PrometheusMetrics
import requests
import os

app = Flask(__name__)
CORS(app)
metrics = PrometheusMetrics(app)

API_KEY = os.environ.get("FOOTBALL_API_KEY", "")

LIGEN = {
    "PL":  "Premier League",
    "BL1": "Bundesliga",
    "PD":  "La Liga",
    "SA":  "Serie A",
    "FL1": "Ligue 1"
}

@app.route("/standings")
def standings():
    liga = request.args.get("liga", "PL")
    url = f"https://api.football-data.org/v4/competitions/{liga}/standings"
    res = requests.get(url, headers={"X-Auth-Token": API_KEY})
    return jsonify(res.json())

@app.route("/health")
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
