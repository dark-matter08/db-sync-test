# Dockerfile for Node.js + Prisma + Express
FROM node:20
WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npx", "nodemon", "--exec", "npx ts-node", "index.ts"]
