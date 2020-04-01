#!/bin/bash

set -eu

CA_HOME=$(pwd)
INTERMEDIATE_CA_HOME="$CA_HOME/intermediate"
INTERMEDIATE_CA_CERTS_DIR="$INTERMEDIATE_CA_HOME/certs"
INTERMEDIATE_CA_PRIVATE_DIR="$INTERMEDIATE_CA_HOME/private"
INTERMEDIATE_CA_CSR_DIR="$INTERMEDIATE_CA_HOME/csr"
REQ_OPENSSL_CNF="openssl.cnf"


list_req_extensions(){
  grep "_ext ]" "$REQ_OPENSSL_CNF" | awk '{print $2}'
}

new_leaf_certificate() {
  local tmp_files
  tmp_files=(
    "$INTERMEDIATE_CA_PRIVATE_DIR/leaf-key.pem"
    "$INTERMEDIATE_CA_CSR_DIR/leaf-csr.pem"
    "$INTERMEDIATE_CA_CERTS_DIR/leaf.pem"
  )
  for f in "${tmp_files[@]}"; do
    if [ -f "$f" ]; then
      echo "Deleting temporary file $f from a previous run"
      rm "$f"
    fi
  done

  echo 'Preparing to create leaf private key...'
  echo '  1) RSA (4096)'
  echo '  2) ECDSA (P-384)'
  read -rp 'Choose: ' leaf_algo

  if [ "$leaf_algo" -eq 1 ]; then
    openssl genrsa -out "$INTERMEDIATE_CA_PRIVATE_DIR/leaf-key.pem" 4096
  else
    openssl ecparam -out "$INTERMEDIATE_CA_PRIVATE_DIR/leaf-key.pem" -name secp384r1 -genkey
  fi

  local req_extensions
  # shellcheck disable=SC2207
  req_extensions=($(list_req_extensions))

  echo 'Choosing a certificate profile...'
  for i in "${!req_extensions[@]}"; do
    echo "$((i+1))) ${req_extensions[$i]}"
  done
  read -rp 'Choose: ' choice_idx

  local cert_ext
  cert_ext="${req_extensions[$((choice_idx-1))]}"

  openssl req -config "$REQ_OPENSSL_CNF" \
    -key "$INTERMEDIATE_CA_PRIVATE_DIR/leaf-key.pem" \
    -new \
    -sha384 \
    -out "$INTERMEDIATE_CA_CSR_DIR/leaf-csr.pem"

  openssl ca -config "$INTERMEDIATE_CA_HOME/intermediate.cnf" \
    -in "$INTERMEDIATE_CA_CSR_DIR/leaf-csr.pem" \
    -extensions "$cert_ext" \
    -notext \
    -md sha384 \
    -out "$INTERMEDIATE_CA_CERTS_DIR/leaf.pem"

  LEAF_CN=$(openssl x509 -in "$INTERMEDIATE_CA_CERTS_DIR/leaf.pem" -noout -subject | awk -v FS="(CN = |emailAddress)" '{print $2}' | sed 's/,//g' | sed 's/ //g')
  mv "$INTERMEDIATE_CA_PRIVATE_DIR/leaf-key.pem" "$INTERMEDIATE_CA_PRIVATE_DIR/$LEAF_CN-key.pem"
  mv "$INTERMEDIATE_CA_CSR_DIR/leaf-csr.pem" "$INTERMEDIATE_CA_CSR_DIR/$LEAF_CN-csr.pem"
  mv "$INTERMEDIATE_CA_CERTS_DIR/leaf.pem" "$INTERMEDIATE_CA_CERTS_DIR/$LEAF_CN.pem"
}

new_leaf_certificate
