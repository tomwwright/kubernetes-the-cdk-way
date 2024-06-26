#!/bin/bash

set -x

# smoke tests for cluster
# as per https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/12-smoke-test.md

# get server version

curl -k --cacert ca.crt \
  https://server.kubernetes.local:6443/version

# create a secret

kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"

# create a deployment

kubectl create deployment nginx \
  --image=nginx:latest

# list the pods

kubectl get pods -l app=nginx

POD_NAME=$(kubectl get pods -l app=nginx \
  -o jsonpath="{.items[0].metadata.name}")

kubectl wait --for=condition=Ready pod/$POD_NAME

# port forwarding for a pod

kubectl port-forward $POD_NAME 8080:80 & # background the port forwarding

curl --head http://127.0.0.1:8080

kill $(jobs -p) # clean up the port forwarding in background

# display logs for a pod

kubectl logs $POD_NAME

# exec command on a pod

kubectl exec -ti $POD_NAME -- nginx -v

# service

kubectl expose deployment nginx \
  --port 80 --type NodePort

NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')

NODE_NAME=$(kubectl get pod $POD_NAME \
  --output=jsonpath='{.spec.nodeName}')

curl -I http://$NODE_NAME:$NODE_PORT