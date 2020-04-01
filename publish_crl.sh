#!/bin/bash
set -eu

CA_HOME=$(pwd)
ROOT_CA_HOME="$CA_HOME/root"
ROOT_CA_CRL_DIR="$ROOT_CA_HOME/crl"
INTERMEDIATE_CA_HOME="$CA_HOME/intermediate"
INTERMEDIATE_CA_CRL_DIR="$INTERMEDIATE_CA_HOME/crl"


gen_root_crl() {
  openssl ca -config "$ROOT_CA_HOME/root.cnf" \
    -gencrl \
    -out "$ROOT_CA_CRL_DIR/crl.pem"
}


gen_intermediate_crl() {
  openssl ca -config "$INTERMEDIATE_CA_HOME/intermediate.cnf" \
    -gencrl \
    -out "$INTERMEDIATE_CA_CRL_DIR/crl.pem"
}


gen_root_crl
gen_intermediate_crl
