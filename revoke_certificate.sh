#!/bin/bash

set -eu

CA_HOME=$(pwd)
INTERMEDIATE_CA_HOME="$CA_HOME/intermediate"
INTERMEDIATE_CA_CERTS_DIR="$INTERMEDIATE_CA_HOME/certs"
INTERMEDIATE_CA_PRIVATE_DIR="$INTERMEDIATE_CA_HOME/private"

# shellcheck disable=SC2206
revoke_leaf_certificate() {
  echo 'Choosing a certificate to revoke...'

  certs=($INTERMEDIATE_CA_CERTS_DIR/*.pem)

  for i in "${!certs[@]}"; do
    echo "$((i+1))) ${certs[$i]}"
  done
  read -rp 'Choose: ' cert_idx

  cert_to_revoke="${certs[$((cert_idx-1))]}"

  if [ "$cert_to_revoke" == "$INTERMEDIATE_CA_CERTS_DIR/intermediate.pem" ]; then
    echo Cannot revoke CA certificate
    exit 1
  fi

  openssl ca -config "$INTERMEDIATE_CA_HOME/intermediate.cnf" \
    -revoke "$cert_to_revoke" \
    -keyfile "$INTERMEDIATE_CA_PRIVATE_DIR/intermediate-key.pem" \
    -cert "$INTERMEDIATE_CA_CERTS_DIR/intermediate.pem"
}

revoke_leaf_certificate
