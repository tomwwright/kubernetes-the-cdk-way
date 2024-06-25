#!/bin/bash

cp kubernetes-the-hard-way/ca.conf ca.conf

openssl genrsa -out ca.key 4096
openssl req -x509 -new -sha512 -noenc \
-key ca.key -days 3653 \
-config ca.conf \
-out ca.crt

certs=(
  "admin" "node-0" "node-1"
  "kube-proxy" "kube-scheduler"
  "kube-controller-manager"
  "kube-api-server"
  "service-accounts"
)

for i in ${certs[*]}; do
  openssl genrsa -out "${i}.key" 4096

  openssl req -new -key "${i}.key" -sha256 \
    -config "ca.conf" -section ${i} \
    -out "${i}.csr"
  
  openssl x509 -req -days 3653 -in "${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${i}.crt"
done

cp ca.crt node-0.crt node-0.key out/node-0
cp ca.crt node-1.crt node-1.key out/node-1
cp ca.key ca.crt \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  out/server