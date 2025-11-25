import os
import time
import threading
from flask import Flask

app = Flask(__name__)

# Global counter to simulate background work
counter = 0
last_update = time.time()

def background_worker():
    global counter, last_update
    print("Background worker started")
    while True:
        # Increment counter every second
        counter += 1
        last_update = time.time()
        # Print every 5 seconds to logs
        if counter % 5 == 0:
            print(f"Background worker: counter is {counter}")
        time.sleep(1)

# Start background thread
thread = threading.Thread(target=background_worker, daemon=True)
thread.start()

@app.route('/')
def status():
    global counter, last_update
    
    # Calculate how many seconds have passed since the last update
    # If CPU is throttled, the background thread won't run, and 'now' will be much larger than 'last_update'
    now = time.time()
    time_diff = now - last_update
    
    status_msg = "RUNNING"
    if time_diff > 2.0:
        status_msg = "THROTTLED / PAUSED"
        
    return f"""
    <h1>Cloud Run CPU Allocation Demo</h1>
    <p><b>Counter:</b> {counter}</p>
    <p><b>Time since last background update:</b> {time_diff:.2f} seconds</p>
    <p><b>Status:</b> {status_msg}</p>
    <hr>
    <p>If CPU is <b>allocated only during request processing</b>, the counter will stop incrementing between requests.</p>
    <p>If CPU is <b>always allocated</b>, the counter will keep incrementing in the background.</p>
    """

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))