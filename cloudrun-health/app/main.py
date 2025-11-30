#!/usr/bin/env python3
"""
Cloud Run Service Health Demo Application

This Flask application demonstrates Cloud Run readiness probes and service health
for automated multi-region failover. It provides endpoints to control the health
status dynamically, allowing you to test failover scenarios.

Endpoints:
    GET  /                     - Main page showing service info
    GET  /health               - Readiness probe endpoint
    POST /set_health           - Set health status (healthy=true/false)
    POST /set_readiness        - Set readiness percentage (percent=0-100)
    GET  /status               - Get current health configuration
"""

import os
import random
import socket
from datetime import datetime
from flask import Flask, request, jsonify, render_template_string

app = Flask(__name__)

# Health configuration (stored in memory - reset on container restart)
health_config = {
    "healthy": True,
    "readiness_percent": 100,
    "last_updated": datetime.utcnow().isoformat(),
    "startup_time": datetime.utcnow().isoformat()
}

# Get metadata from environment/metadata service
def get_region():
    """Get the Cloud Run region from K_SERVICE environment or metadata."""
    # Try environment variable first (set in Cloud Run)
    region = os.environ.get("CLOUD_RUN_REGION", "")
    if region:
        return region
    
    # Fall back to metadata service
    try:
        import urllib.request
        req = urllib.request.Request(
            "http://metadata.google.internal/computeMetadata/v1/instance/region",
            headers={"Metadata-Flavor": "Google"}
        )
        with urllib.request.urlopen(req, timeout=1) as response:
            # Returns format: projects/PROJECT_NUMBER/regions/REGION
            full_region = response.read().decode()
            return full_region.split("/")[-1]
    except Exception:
        return "unknown"

def get_instance_id():
    """Get the Cloud Run instance ID."""
    return os.environ.get("K_REVISION", "unknown") + "-" + socket.gethostname()[:8]

def get_service_name():
    """Get the Cloud Run service name."""
    return os.environ.get("K_SERVICE", "health-demo")

# HTML template for the main page
MAIN_PAGE_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>Cloud Run Service Health Demo</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 900px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .card {
            background: white;
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 { color: #1a73e8; margin-top: 0; }
        h2 { color: #5f6368; margin-top: 0; }
        .status {
            display: inline-block;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: bold;
            font-size: 14px;
        }
        .healthy { background: #e6f4ea; color: #1e8e3e; }
        .unhealthy { background: #fce8e6; color: #d93025; }
        .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin: 20px 0;
        }
        .info-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
        }
        .info-label {
            color: #5f6368;
            font-size: 12px;
            text-transform: uppercase;
            margin-bottom: 5px;
        }
        .info-value {
            color: #202124;
            font-size: 14px;
            font-weight: 500;
            font-family: monospace;
            word-break: break-all;
            overflow-wrap: anywhere;
            white-space: normal;
        }
        .controls {
            margin-top: 20px;
        }
        button {
            background: #1a73e8;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 6px;
            font-size: 14px;
            cursor: pointer;
            margin-right: 10px;
            margin-bottom: 10px;
        }
        button:hover { background: #1557b0; }
        button.danger { background: #d93025; }
        button.danger:hover { background: #b3261e; }
        button.success { background: #1e8e3e; }
        button.success:hover { background: #137333; }
        input[type="range"] {
            width: 200px;
            margin: 0 10px;
        }
        code {
            background: #f1f3f4;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 13px;
        }
        pre {
            background: #202124;
            color: #e8eaed;
            padding: 20px;
            border-radius: 8px;
            overflow-x: auto;
        }
        .region-badge {
            display: inline-block;
            background: #e8f0fe;
            color: #1a73e8;
            padding: 4px 12px;
            border-radius: 4px;
            font-size: 14px;
            font-weight: 500;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>☁️ Cloud Run Service Health Demo</h1>
        <p>This service demonstrates <strong>readiness probes</strong> and <strong>automated multi-region failover</strong>.</p>
        
        <div class="info-grid">
            <div class="info-item">
                <div class="info-label">Region</div>
                <div class="info-value"><span class="region-badge">{{ region }}</span></div>
            </div>
            <div class="info-item">
                <div class="info-label">Health Status</div>
                <div class="info-value">
                    <span class="status {{ 'healthy' if healthy else 'unhealthy' }}">
                        {{ '✓ HEALTHY' if healthy else '✗ UNHEALTHY' }}
                    </span>
                </div>
            </div>
            <div class="info-item">
                <div class="info-label">Service Name</div>
                <div class="info-value">{{ service }}</div>
            </div>
            <div class="info-item">
                <div class="info-label">Instance ID</div>
                <div class="info-value">{{ instance }}</div>
            </div>
            <div class="info-item">
                <div class="info-label">Readiness Percent</div>
                <div class="info-value">{{ readiness_percent }}%</div>
            </div>
            <div class="info-item">
                <div class="info-label">Last Updated</div>
                <div class="info-value">{{ last_updated }}</div>
            </div>
        </div>
    </div>

    <div class="card">
        <h2>🎛️ Health Controls</h2>
        <p>Use these controls to simulate health changes and test failover:</p>
        
        <div class="controls">
            <button class="success" onclick="setHealth(true)">Set Healthy</button>
            <button class="danger" onclick="setHealth(false)">Set Unhealthy</button>
        </div>
        
        <div class="controls" style="margin-top: 20px;">
            <label>Readiness Percent: <span id="percentValue">{{ readiness_percent }}</span>%</label>
            <br><br>
            <input type="range" id="percentSlider" min="0" max="100" value="{{ readiness_percent }}" 
                   oninput="document.getElementById('percentValue').textContent = this.value">
            <button onclick="setReadiness(document.getElementById('percentSlider').value)">Apply</button>
        </div>
    </div>

    <div class="card">
        <h2>📡 API Endpoints</h2>
        <pre>
# Check health status (readiness probe)
curl {{ request_url }}/health

# Set service as unhealthy (triggers failover)
curl -X POST "{{ request_url }}/set_health?healthy=false"

# Set service as healthy (allows failback)
curl -X POST "{{ request_url }}/set_health?healthy=true"

# Set readiness percentage (0-100)
curl -X POST "{{ request_url }}/set_readiness?percent=50"

# Get current status
curl {{ request_url }}/status
        </pre>
    </div>

    <script>
        async function setHealth(healthy) {
            const response = await fetch(`/set_health?healthy=${healthy}`, { method: 'POST' });
            const data = await response.json();
            alert(data.message);
            location.reload();
        }
        
        async function setReadiness(percent) {
            const response = await fetch(`/set_readiness?percent=${percent}`, { method: 'POST' });
            const data = await response.json();
            alert(data.message);
            location.reload();
        }
    </script>
</body>
</html>
"""


@app.route("/")
def index():
    """Main page showing service info and health controls."""
    # Get the request URL for display
    request_url = request.url_root.rstrip("/")
    
    return render_template_string(
        MAIN_PAGE_HTML,
        region=get_region(),
        service=get_service_name(),
        instance=get_instance_id(),
        healthy=health_config["healthy"],
        readiness_percent=health_config["readiness_percent"],
        last_updated=health_config["last_updated"],
        request_url=request_url
    )


@app.route("/health")
def health():
    """
    Readiness probe endpoint.
    
    Returns 200 if healthy, 503 if unhealthy.
    When readiness_percent < 100, randomly returns unhealthy for that percentage.
    """
    # Check if we should be healthy based on percentage
    if health_config["readiness_percent"] < 100:
        if random.randint(1, 100) > health_config["readiness_percent"]:
            return jsonify({
                "status": "unhealthy",
                "reason": "random_failure",
                "readiness_percent": health_config["readiness_percent"],
                "region": get_region(),
                "instance": get_instance_id()
            }), 503
    
    # Check explicit health setting
    if not health_config["healthy"]:
        return jsonify({
            "status": "unhealthy",
            "reason": "manually_set_unhealthy",
            "region": get_region(),
            "instance": get_instance_id()
        }), 503
    
    return jsonify({
        "status": "healthy",
        "region": get_region(),
        "instance": get_instance_id()
    }), 200


@app.route("/set_health", methods=["POST"])
def set_health():
    """
    Set the health status of this instance.
    
    Query params:
        healthy: true or false
    """
    healthy_param = request.args.get("healthy", "true").lower()
    health_config["healthy"] = healthy_param in ("true", "1", "yes")
    health_config["last_updated"] = datetime.utcnow().isoformat()
    
    return jsonify({
        "message": f"Health set to {'healthy' if health_config['healthy'] else 'unhealthy'}",
        "healthy": health_config["healthy"],
        "region": get_region(),
        "instance": get_instance_id()
    })


@app.route("/set_readiness", methods=["POST"])
def set_readiness():
    """
    Set the readiness percentage.
    
    Query params:
        percent: 0-100 (percentage of successful health checks)
    """
    try:
        percent = int(request.args.get("percent", "100"))
        percent = max(0, min(100, percent))  # Clamp to 0-100
    except ValueError:
        percent = 100
    
    health_config["readiness_percent"] = percent
    health_config["last_updated"] = datetime.utcnow().isoformat()
    
    return jsonify({
        "message": f"Readiness percent set to {percent}%",
        "readiness_percent": percent,
        "region": get_region(),
        "instance": get_instance_id()
    })


@app.route("/status")
def status():
    """Get the current health configuration and service info."""
    return jsonify({
        "healthy": health_config["healthy"],
        "readiness_percent": health_config["readiness_percent"],
        "last_updated": health_config["last_updated"],
        "startup_time": health_config["startup_time"],
        "region": get_region(),
        "service": get_service_name(),
        "instance": get_instance_id()
    })


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)