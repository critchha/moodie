# syntax=docker/dockerfile:1
FROM node:20-slim

WORKDIR /app

# Install dependencies
COPY package.json ./
COPY package-lock.json ./
RUN npm ci --omit=dev

# Copy frontend code
COPY . .

# Build Next.js app
RUN npm run build

ENV NODE_ENV=production
EXPOSE 3000

CMD ["npm", "start"] 