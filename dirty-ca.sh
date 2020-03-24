#!/usr/bin/env bash

set -eu

CA_HOME=./ca

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
    "$CA_HOME"
    "$ROOT_CA_HOME"
    "$ROOT_CA_NEW_CERTS_DIR"
    "$ROOT_CA_CERTS_DIR"
    "$ROOT_CA_PRIVATE_DIR"
    "$ROOT_CA_CRL_DIR"
    "$INTERMEDIATE_CA_HOME"
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
      echo "Directory $d already present, skipping"
    else
      mkdir -p "$d"
    fi
  done

  for f in "${CA_FILES[@]}"; do
    if [ -f "$f" ]; then
      echo "File $f already present, skipping"
    else
      touch "$f"
    fi
  done

  echo 1000 > "$ROOT_CA_SERIAL"
  echo 1000 > "$INTERMEDIATE_CA_SERIAL"
  echo 1000 > "$ROOT_CA_CRL_NUMBER"
  echo 1000 > "$INTERMEDIATE_CA_CRL_NUMBER"
}

init_root_ca() {
  echo 'Preparing to create root CA private key...'
  echo '  1) RSA'
  echo '  2) ECDSA'
  read -rp 'Choose: ' root_algo

  if [ "$root_algo" -eq 1 ]; then
    openssl genrsa -out $ROOT_CA_PRIVATE_DIR/root-key.pem 4096
  else
    openssl ecparam -out $ROOT_CA_PRIVATE_DIR/root-key.pem -name secp384r1 -genkey
  fi

  openssl req -config ./root.cnf \
    -key $ROOT_CA_PRIVATE_DIR/root-key.pem \
    -new \
    -x509 \
    -days 1825 \
    -sha384 \
    -extensions v3_ca \
    -out $ROOT_CA_CERTS_DIR/root.pem
}

gen_root_crl() {
  openssl ca -config root.cnf \
    -gencrl \
    -out $ROOT_CA_CRL_DIR/crl.pem
}

init_intermediate_ca() {
  echo 'Preparing to create intermediate CA private key...'
  echo '  1) RSA'
  echo '  2) ECDSA'
  read -rp 'Choose: ' int_algo

  if [ "$int_algo" -eq 1 ]; then
    openssl genrsa -out $INTERMEDIATE_CA_PRIVATE_DIR/intermediate-key.pem 4096
  else
    openssl ecparam -out $INTERMEDIATE_CA_PRIVATE_DIR/intermediate-key.pem -name secp384r1 -genkey
  fi

  openssl req -config ./intermediate.cnf \
    -key $INTERMEDIATE_CA_PRIVATE_DIR/intermediate-key.pem \
    -new \
    -sha256 \
    -out $INTERMEDIATE_CA_CSR_DIR/intermediate-csr.pem

  openssl ca -config root.cnf \
    -in $INTERMEDIATE_CA_CSR_DIR/intermediate-csr.pem \
    -extensions v3_intermediate_ca \
    -days 365 \
    -notext \
    -md sha256 \
    -out $INTERMEDIATE_CA_CERTS_DIR/intermediate.pem

  cat $INTERMEDIATE_CA_CERTS_DIR/intermediate.pem $ROOT_CA_CERTS_DIR/root.pem > $CA_HOME/ca.pem
}

gen_intermediate_crl() {
  openssl ca -config intermediate.cnf \
    -gencrl \
    -out $INTERMEDIATE_CA_CRL_DIR/crl.pem
}

init_leaf_certificate() {
  echo 'Preparing to create leaf private key...'
  echo '  1) RSA'
  echo '  2) ECDSA'
  read -rp 'Choose: ' leaf_algo

  if [ "$leaf_algo" -eq 1 ]; then
    openssl genrsa -out $INTERMEDIATE_CA_PRIVATE_DIR/leaf-key.pem
  else
    openssl ecparam -out $INTERMEDIATE_CA_PRIVATE_DIR/leaf-key.pem -name secp384r1 -genkey
  fi

  echo 'Choosing a certificate profile...'
  echo '  1) client'
  echo '  2) server'
  read -rp 'Choose: ' cert_profile

  if [ "$cert_profile" -eq 1 ]; then
    CERT_EXT="usr_cert"
  else
    CERT_EXT="server_cert"
  fi

  openssl req -config ./intermediate.cnf \
    -key $INTERMEDIATE_CA_PRIVATE_DIR/leaf-key.pem \
    -new \
    -sha256 \
    -out $INTERMEDIATE_CA_CSR_DIR/leaf-csr.pem

  openssl ca -config intermediate.cnf \
    -in $INTERMEDIATE_CA_CSR_DIR/leaf-csr.pem \
    -extensions $CERT_EXT \
    -notext \
    -md sha256 \
    -out $INTERMEDIATE_CA_CERTS_DIR/leaf.pem

  LEAF_CN=$(openssl x509 -in $INTERMEDIATE_CA_CERTS_DIR/leaf.pem -noout -subject | awk -v FS="(CN = |emailAddress)" '{print $2}' | sed 's/,//g' | sed 's/ //g')
  mv $INTERMEDIATE_CA_PRIVATE_DIR/leaf-key.pem "$INTERMEDIATE_CA_PRIVATE_DIR/$LEAF_CN-key.pem"
  mv $INTERMEDIATE_CA_CSR_DIR/leaf-csr.pem "$INTERMEDIATE_CA_CSR_DIR/$LEAF_CN-csr.pem"
  mv $INTERMEDIATE_CA_CERTS_DIR/leaf.pem "$INTERMEDIATE_CA_CERTS_DIR/$LEAF_CN.pem"
}

init() {
  init_ca_dir
  init_root_ca
  init_intermediate_ca
}

delete_ca() {
  rm -rf ca
}

echo_help() {
  echo 'Run a hacky CA anywhere!'
  echo ''
  echo '  -h  Print help text'
  echo '  -i  Initialize CA (create root and intermediate pairs)'
  echo '  -D  Cleanup existing hacky CA (contents of the ./ca directory)'
  echo '  -c  Create new CRLs for both the root and intermediate CA (check ca/*/crl)'
  echo '  -L  Create a leaf certificate with the already existing CA (Run w/ -i first!)'
}

while getopts ':hiDcL' option; do
  case "$option" in
    h) echo_help
       exit
       ;;
    i) init
       exit
       ;;
    c) gen_root_crl
       gen_intermediate_crl
       exit
       ;;
    D) delete_ca
       exit
       ;;
    L) init_leaf_certificate
       exit
       ;;
    *) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo_help
       exit 1
       ;;
  esac
done
shift $((OPTIND - 1))
