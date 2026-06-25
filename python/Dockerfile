FROM python:3.11-slim AS builder

WORKDIR /app

RUN pip install --no-cache-dir --prefix=/install flask gunicorn

FROM python:3.11-slim AS final

WORKDIR /app

COPY --from=builder /install /usr/local
COPY app.py .

USER 10001

EXPOSE 8080
ENV PORT=8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "app:app"]
