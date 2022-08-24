#!/usr/bin/env bash

if [ -z "$1" ]; then

  echo "Usage: $0 somedomain.com"
  echo "Will generate *.somedomain.com KEY, CSR, CRT files"
  exit 1

fi

# Usage
DOMAIN=$1

if [ -f "ca.crt" ] || [ -f "ca.key" ]; then
    echo -e "\e[41mCertificate Authority files already exist!\e[49m"
    echo
    echo -e "You only need a single CA even if you need to create multiple certificates."
    echo -e "This way, you only ever have to import the certificate in your browser once."
    echo
    echo -e "If you want to restart from scratch, delete the \e[93mca.crt\e[39m and \e[93mca.key\e[39m files."
    exit
fi

set -e

# Generate private key
openssl genrsa -out ca.key 4096

ROOT_CSR="
C=PL
O=SparkHome Development CA
CN=SparkHome CA
"

# Generate the root certificate
openssl req -x509 -new -nodes -subj "$(echo -n "$ROOT_CSR" | tr "\n" "/")" -key ca.key -sha256 -days 3650 -out ca.crt

if [ ! -f "ca.key" ]; then
    echo -e "\e[41mCertificate Authority private key does not exist!\e[49m"
    echo
    echo -e "Please run \e[93mcreate-ca.sh\e[39m first."
    exit
fi

# Generate a private key
openssl genrsa -out "$DOMAIN.key" 4096

WILDCARD_CSR="
C=PL
O=Wildcard local dev
CN=$DOMAIN
"

# Create a certificate signing request
openssl req -new -subj "$(echo -n "$WILDCARD_CSR" | tr "\n" "/")" -key "$DOMAIN.key" -out "$DOMAIN.csr"

# Create a config file for the extensions
>"$DOMAIN.ext" cat <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
EOF

# Create the signed certificate
openssl x509 -req \
    -in "$DOMAIN.csr" \
    -extfile "$DOMAIN.ext" \
    -CA ca.crt \
    -CAkey ca.key \
    -CAcreateserial \
    -out "$DOMAIN.crt" \
    -days 365 \
    -sha256

rm "$DOMAIN.csr"
rm "$DOMAIN.ext"

cat ca.crt > "$DOMAIN"-bundle.crt
cat "$DOMAIN".crt > "$DOMAIN"-bundle.crt
