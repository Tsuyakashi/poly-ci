import datetime
import logging
import os
from flask import Flask, request

logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s in %(module)s: %(message)s'
)

app = Flask(__name__)

def get_cpu_load():
    try:
        with open("/proc/loadavg", "r") as f:
            load_1min = f.read().split()[0]
        return load_1min
    except Exception as e:
        app.logger.error(f"Failed to get CPU load: {e}")
        return "N/A"

@app.before_request
def log_request_info():
    if request.path != '/health':  # чтобы не спамить логами хелсчеков
        app.logger.info(f"HTTP {request.method} {request.path} from {request.remote_addr}")

@app.route('/')
def hello_world():
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cpu_load = get_cpu_load()
    
    return f"""
    <html>
    <head><title>BSUIR DevOps App</title></head>
    <body style="font-family:sans-serif; background:#121212; color:#fff; text-align:center; padding-top:50px;">
        <h2>Hello World!</h2>
        <p>Timestamp: <b>{timestamp}</b></p>
        <p>System Load (1 min): <b>{cpu_load}</b></p>
    </body>
    </html>
    """

@app.route('/health')
def healthcheck():
    return { "status": "ok" }
