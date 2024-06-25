#!/bin/bash

echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts
while read IP FQDN HOST SUBNET; do 
  ENTRY="${IP} ${FQDN} ${HOST}"
  echo $ENTRY >> hosts
done < machines.txt

cp hosts out/server
cp hosts out/node-0
cp hosts out/node-1