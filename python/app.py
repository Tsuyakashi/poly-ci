# app.py
from flask import Flask
import datetime

app = Flask(__name__)

def get_cpu_load():
    try:
        with open("/proc/loadavg", "r") as f:
            # Берём первое число — средняя загрузка за последнюю 1 минуту
            load_1min = f.read().split()[0]
        return load_1min
    except Exception:
        return "N/A"

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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)