FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY app.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /app app.go

FROM scratch
COPY --from=builder /app /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

EXPOSE 8080
ENTRYPOINT ["/app"]
