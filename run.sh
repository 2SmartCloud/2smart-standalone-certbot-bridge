#!/bin/sh

if [ -z "$DOMAIN" ]; then
  echo "### ERROR: DOMAIN is required!"
  exit 1
fi

if [ -z "$USER_EMAIL" ]; then
  echo "### ERROR: USER_EMAIL is required!"
  exit 1
fi

if [ -z "$STAGING" ]; then
  STAGING=0
fi

domain=$DOMAIN
rsa_key_size=4096
dir_path=/etc/letsencrypt/live/$DOMAIN

cert_path=/app/ssl/certs/server-cert.pem
key_path=/app/ssl/private/server-key.pem

htpasswd_file_path=/var/www/shared/.htpasswd

error_handler() {
  error_message=$1

  if [ -z "$error_message" ]; then
    error_message="Unknown error..."
  fi

  echo "### ERROR: $error_message"

  exit 1
}

event() {
  echo "@event::$1::@end"
}

request_cert() {
  echo "### Requesting Let's Encrypt certificate for $DOMAIN ..."

  ## ARGS ##

  # Enable staging mode if needed
  if [ $STAGING != "0" ]; then staging_arg="--staging"; fi

  domain_args="-d $DOMAIN"
  email_arg="--email $USER_EMAIL"

  certbot certonly --webroot -w /var/www/shared \
    $staging_arg \
    $email_arg \
    $domain_args \
    --keep-until-expiring \
    --rsa-key-size $rsa_key_size \
    --agree-tos || error_handler "An error occurred while requesting certificate..."

  copy_certs

  echo "### Reloading nginx..."
  event "service.finish" ## trigger 2smart-core for event
}

copy_certs() {
  echo "### Copying certificates..."

  cp "$dir_path/fullchain.pem" $cert_path || error_handler "An error occurred while copying certificate..."
  cp "$dir_path/privkey.pem" $key_path || error_handler "An error occurred while copying private key..."

  echo "### Copying end..."
}

request_cert

## generate basic auth file if username is specified
if [ ! -z "$BASIC_AUTH_USERNAME" ]; then
  echo "### Basic auth username specified..."

  ## -c create new file
  ## -b batch mode to specify username/password
  htpasswd_args="-b -c"

  echo "### Executing: htpasswd $htpasswd_args $htpasswd_file_path"

  htpasswd $htpasswd_args $htpasswd_file_path $BASIC_AUTH_USERNAME "$BASIC_AUTH_PASSWORD" || error_handler "An error occurred while creating basic auth configuration..."
else
  ## remove all basic auth entries
  rm $htpasswd_file_path
fi

echo "### Start renew watcher..."

## Function to setup watcher
trap exit TERM;
while :;
  do
    echo "### Calling certbot renew..."

    certbot renew
    copy_certs

    event "service.update"

    sleep 12h
done;
