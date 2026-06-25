# --- Stage 1: Build ---
FROM golang:1.22-alpine AS builder

WORKDIR /src

# Если у тебя есть go.mod и go.sum, раскомментируй эти строки:
# COPY go.mod go.sum ./
# RUN go mod download

COPY app.go ./

# Собираем статически скомпилированный бинарь без CGO
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /bin/demo app.go

# --- Stage 2: Final ---
FROM scratch

# Копируем бинарник из билдера
COPY --from=builder /bin/demo /bin/demo

# (Опционально) Если приложение будет ходить в интернет по HTTPS, 
# понадобятся SSL-сертификаты, берем их из билдера:
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

EXPOSE 8080

ENTRYPOINT ["/bin/demo"]