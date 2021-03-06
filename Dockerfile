# === default images ===
ARG IMAGE_NODE=node:alpine
ARG IMAGE_NGINX=nginx:alpine
ARG IMAGE_SYSMAKER_ENV=sysmaker/sysmaker-env:latest

# === base stage ===
FROM $IMAGE_SYSMAKER_ENV as base
LABEL sysmaker="build"

ARG IMAGE_SYSMAKER_ENV
WORKDIR /sysmaker/
COPY sysmaker/ misc/nginx-confd/app.conf ./

RUN echo "Image: $IMAGE_SYSMAKER_ENV" \
    && npm run sysmaker:build \
    && rm -rf package-lock.json node_modules \
    && find dist/apps/sysmaker \( -name '*.js' -o -name '*.css' \) -type f -exec gzip -9 -k "{}" \; \
    \
    && npm install @nestjs/common @nestjs/core @nestjs/platform-express reflect-metadata rxjs tslib \
    && cp -r node_modules/ dist/apps/api/


# === APP ===
FROM $IMAGE_NGINX as sysmaker-app
LABEL maintainer="LouisSung <ls@sysmaker.org>" \
      description="Sysmaker APP" \
      sysmaker="app"

COPY --from=base /sysmaker/dist/apps/sysmaker/ /usr/share/nginx/html/
COPY --from=base /sysmaker/app.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]


# === API ===
FROM $IMAGE_NODE as sysmaker-api
LABEL maintainer="LouisSung <ls@sysmaker.org>" \
      description="Sysmaker API" \
      sysmaker="api"

WORKDIR /sysmaker/api/
COPY --from=base /sysmaker/dist/apps/api/ /sysmaker/api/

ENV port=80
EXPOSE 80
CMD ["node", "/sysmaker/api/main.js"]


# === SINGLE ===
FROM $IMAGE_NODE as sysmaker-single
LABEL maintainer="LouisSung <ls@sysmaker.org>" \
      description="Sysmaker" \
      sysmaker="single"

WORKDIR /sysmaker/
COPY --from=base /sysmaker/dist/apps/sysmaker/ /usr/share/nginx/html/
COPY --from=base /sysmaker/dist/apps/api/ /sysmaker/api/

RUN apk update && apk add --no-cache nginx && mkdir -p /var/run/nginx

EXPOSE 80
EXPOSE 443
ENTRYPOINT []
CMD ["sh", "-c", "nginx & nohup node /sysmaker/api/main.js"]
