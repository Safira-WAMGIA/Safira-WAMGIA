FROM node:18-alpine
WORKDIR /app

RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    udev \
    tzdata

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

COPY . .
RUN npm install express
EXPOSE 3000
CMD ["node", "main.js"]
