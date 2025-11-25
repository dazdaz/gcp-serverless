FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

# Sidecar listens on 8081
CMD ["gunicorn", "--bind", ":8081", "--workers", "1", "--threads", "8", "--timeout", "0", "main:app"]