# Dirty CA

An OpenSSL CA hacky enough that I can use it for various testing.

**NOTE: This is meant for test purposes only. Don't run any domain you care about off it**

## Usage

1. Create a root and intermediate CA with the provided [init.sh](init.sh)
1. Create n leaf certificates with the provided [leaf.sh](leaf.sh)
1. Revoke certs if you want with [revoke_certificates.sh](revoke_certificates.sh)
1. Generate updated CRLs with [publish_crl.sh](public_crl.sh)

## TODO

1. Add a vagrant file
1. Support actually hosting the CRLs being "published"
1. Write the necessary plumbing to run an OCSP responder
