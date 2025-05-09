# syntax=docker/dockerfile:1
FROM node:20

WORKDIR /app

# Install build tools for native modules
RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY package.json ./
COPY package-lock.json ./
RUN rm -rf node_modules
RUN npm ci

# Copy frontend code
COPY . .

# Debug: check that tailwindcss is installed
RUN ls -la node_modules && npm list tailwindcss && cat package.json

# Build Next.js app
RUN npm run build

ENV NODE_ENV=production
EXPOSE 3000

CMD ["npm", "start"] 