#!/bin/bash

set -eu

CA_HOME=$(pwd)

ROOT_CA_HOME="$CA_HOME/root"
ROOT_CA_CERTS_DIR="$ROOT_CA_HOME/certs"
ROOT_CA_NEW_CERTS_DIR="$ROOT_CA_HOME/newcerts"
ROOT_CA_PRIVATE_DIR="$ROOT_CA_HOME/private"
ROOT_CA_CRL_DIR="$ROOT_CA_HOME/crl"
ROOT_CA_CRL_NUMBER="$ROOT_CA_HOME/crlnumber"
ROOT_CA_DATABASE="$ROOT_CA_HOME/index.txt"
ROOT_CA_SERIAL="$ROOT_CA_HOME/serial"
ROOT_CA_RAND_FILE="$ROOT_CA_PRIVATE_DIR/.rand"

INTERMEDIATE_CA_HOME="$CA_HOME/intermediate"
INTERMEDIATE_CA_CERTS_DIR="$INTERMEDIATE_CA_HOME/certs"
INTERMEDIATE_CA_NEW_CERTS_DIR="$INTERMEDIATE_CA_HOME/newcerts"
INTERMEDIATE_CA_PRIVATE_DIR="$INTERMEDIATE_CA_HOME/private"
INTERMEDIATE_CA_CRL_DIR="$INTERMEDIATE_CA_HOME/crl"
INTERMEDIATE_CA_CSR_DIR="$INTERMEDIATE_CA_HOME/csr"
INTERMEDIATE_CA_CRL_NUMBER="$INTERMEDIATE_CA_HOME/crlnumber"
INTERMEDIATE_CA_DATABASE="$INTERMEDIATE_CA_HOME/index.txt"
INTERMEDIATE_CA_SERIAL="$INTERMEDIATE_CA_HOME/serial"
INTERMEDIATE_CA_RAND_FILE="$INTERMEDIATE_CA_PRIVATE_DIR/.rand"


init_ca_dir() {
  CA_DIRS=(
    "$ROOT_CA_NEW_CERTS_DIR"
    "$ROOT_CA_CERTS_DIR"
    "$ROOT_CA_PRIVATE_DIR"
    "$ROOT_CA_CRL_DIR"
    "$INTERMEDIATE_CA_CERTS_DIR"
    "$INTERMEDIATE_CA_NEW_CERTS_DIR"
    "$INTERMEDIATE_CA_PRIVATE_DIR"
    "$INTERMEDIATE_CA_CRL_DIR"
    "$INTERMEDIATE_CA_CSR_DIR"
  )

  CA_FILES=(
    "$ROOT_CA_CRL_NUMBER"
    "$ROOT_CA_DATABASE"
    "$ROOT_CA_SERIAL"
    "$ROOT_CA_RAND_FILE"
    "$INTERMEDIATE_CA_CRL_NUMBER"
    "$INTERMEDIATE_CA_DATABASE"
    "$INTERMEDIATE_CA_SERIAL"
    "$INTERMEDIATE_CA_RAND_FILE"
  )

  for d in "${CA_DIRS[@]}"; do
    if [ -d "$d" ]; then
      rm -rf "$d"
    fi
    mkdir -p "$d"
  done

  for f in "${CA_FILES[@]}"; do
    if [ -f "$f" ]; then
      rm "$f"
    fi
    touch "$f"
  done

  echo 1000 > "$ROOT_CA_SERIAL"
  echo 1000 > "$INTERMEDIATE_CA_SERIAL"
  echo 1000 > "$ROOT_CA_CRL_NUMBER"
  echo 1000 > "$INTERMEDIATE_CA_CRL_NUMBER"
}

init_root_ca() {
  echo 'Preparing to create root CA private key...'
  echo '  1) RSA (4096)'
  echo '  2) ECDSA (P-384)'
  read -rp 'Choose: ' root_algo

  if [ "$root_algo" -eq 1 ]; then
    openssl genrsa -out "$ROOT_CA_PRIVATE_DIR/root-key.pem" 4096
  else
    openssl ecparam -out "$ROOT_CA_PRIVATE_DIR/root-key.pem" -name secp384r1 -genkey
  fi

  openssl req -config "$ROOT_CA_HOME/root.cnf" \
    -key "$ROOT_CA_PRIVATE_DIR/root-key.pem" \
    -new \
    -x509 \
    -days 1825 \
    -sha384 \
    -extensions root_ca_ext \
    -out "$ROOT_CA_CERTS_DIR/root.pem"
}

init_intermediate_ca() {
  echo 'Preparing to create intermediate CA private key...'
  echo '  1) RSA (4096)'
  echo '  2) ECDSA (P-384)'
  read -rp 'Choose: ' int_algo

  if [ "$int_algo" -eq 1 ]; then
    openssl genrsa -out "$INTERMEDIATE_CA_PRIVATE_DIR/intermediate-key.pem" 4096
  else
    openssl ecparam -out "$INTERMEDIATE_CA_PRIVATE_DIR/intermediate-key.pem" -name secp384r1 -genkey
  fi

  openssl req -config "$INTERMEDIATE_CA_HOME/intermediate.cnf" \
    -key "$INTERMEDIATE_CA_PRIVATE_DIR/intermediate-key.pem" \
    -new \
    -sha384 \
    -out "$INTERMEDIATE_CA_CSR_DIR/intermediate-csr.pem"

  openssl ca -config "$ROOT_CA_HOME/root.cnf" \
    -in "$INTERMEDIATE_CA_CSR_DIR/intermediate-csr.pem" \
    -extensions intermediate_ca_ext \
    -days 365 \
    -notext \
    -md sha384 \
    -out "$INTERMEDIATE_CA_CERTS_DIR/intermediate.pem"
}

init_ca_chain() {
  cat "$INTERMEDIATE_CA_CERTS_DIR/intermediate.pem" "$ROOT_CA_CERTS_DIR/root.pem" > "$CA_HOME/ca.pem"
}


init_ca_dir
init_root_ca
init_intermediate_ca
init_ca_chain
