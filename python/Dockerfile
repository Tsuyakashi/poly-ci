# --- Stage 1: Build ---
FROM python:3.11-slim AS builder

WORKDIR /app

# Устанавливаем зависимости во временный каталог /install
RUN pip install --no-cache-dir --prefix=/install flask gunicorn

# --- Stage 2: Final ---
FROM python:3.11-slim AS final

WORKDIR /app

# Копируем только установленные библиотеки и наш код
COPY --from=builder /install /usr/local
COPY app.py .

# Безопасность: запускаем не под root
USER cookbook:33

EXPOSE 8080

# Переменная окружения для Gunicorn
ENV PORT=8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "app:app"]