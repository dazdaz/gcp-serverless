import os
import requests
from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello_world():
    # The sidecar is accessible on localhost at the port defined in the sidecar container
    sidecar_url = 'http://localhost:8081'
    
    try:
        response = requests.get(sidecar_url)
        sidecar_message = response.text
        status = "SUCCESS"
    except requests.exceptions.RequestException as e:
        sidecar_message = f"Error contacting sidecar: {e}"
        status = "FAILURE"

    return f"""
<h1>Cloud Run Sidecar Demo</h1>
<p>This is the <b>Main Application</b> container running on port {os.environ.get('PORT', 8080)}.</p>
<p>I attempted to contact the <b>Sidecar</b> container on <code>{sidecar_url}</code>.</p>
<hr>
<h3>Result: {status}</h3>
<p><b>Sidecar Response:</b> {sidecar_message}</p>
<hr>
<p><i>Note: In Cloud Run, all containers in a service share the same network namespace (localhost).</i></p>
"""

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))