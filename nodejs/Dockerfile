FROM node:20-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install morgan && npm ci --only=production

FROM node:20-alpine AS final

WORKDIR /usr/src/app

COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY package*.json ./
COPY app.js .

USER node

EXPOSE 8080
ENV PORT=8080
ENV NODE_ENV=production

CMD [ "node", "app.js" ]
