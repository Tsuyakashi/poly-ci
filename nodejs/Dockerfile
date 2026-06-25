# --- Stage 1: Build ---
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./
# Устанавливаем morgan, если еще не поставили
RUN npm install morgan && npm ci --only=production

# --- Stage 2: Final ---
FROM node:20-alpine AS final

WORKDIR /usr/src/app

# Копируем продакшн зависимости и исходники
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY package*.json ./
COPY app.js .

# В alpine образах node уже есть встроенный безопасный пользователь node
USER node

EXPOSE 8080
ENV PORT=8080
ENV NODE_ENV=production

CMD [ "node", "app.js" ]