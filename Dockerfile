FROM certbot/certbot:v1.5.0

WORKDIR /app

RUN apk update && apk add openssl apache2-utils

COPY run.sh run.sh

ENTRYPOINT ["sh", "./run.sh"]