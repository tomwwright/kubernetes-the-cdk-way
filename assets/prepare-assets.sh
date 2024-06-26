#!/bin/bash

set -xe

# ====================================
# bundle configuration files
# ====================================

# control node configurations

cp kubernetes-the-hard-way/units/etcd.service \
  kubernetes-the-hard-way/units/kube-apiserver.service \
  kubernetes-the-hard-way/units/kube-controller-manager.service \
  kubernetes-the-hard-way/units/kube-scheduler.service \
  kubernetes-the-hard-way/configs/kube-scheduler.yaml \
  kubernetes-the-hard-way/configs/kube-apiserver-to-kubelet.yaml \
  out/server

# worker node configurations

for host in node-0 node-1; do
  subnet=$(grep $host machines.txt | cut -d " " -f 4)
  sed "s|SUBNET|$subnet|g" kubernetes-the-hard-way/configs/10-bridge.conf > 10-bridge.conf 
  sed "s|SUBNET|$subnet|g" kubernetes-the-hard-way/configs/kubelet-config.yaml > kubelet-config.yaml
  
  cp 10-bridge.conf kubelet-config.yaml \
    kubernetes-the-hard-way/configs/99-loopback.conf \
    kubernetes-the-hard-way/configs/containerd-config.toml \
    kubernetes-the-hard-way/configs/kubelet-config.yaml \
    kubernetes-the-hard-way/configs/kube-proxy-config.yaml \
    kubernetes-the-hard-way/units/containerd.service \
    kubernetes-the-hard-way/units/kubelet.service \
    kubernetes-the-hard-way/units/kube-proxy.service \
    out/$host
done

# ====================================
# hosts configuration
# see https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md
# ====================================

echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts
while read IP FQDN HOST SUBNET; do 
  ENTRY="${IP} ${FQDN} ${HOST}"
  echo $ENTRY >> hosts
done < machines.txt

cp hosts out/server
cp hosts out/node-0
cp hosts out/node-1
cp hosts out/jumpbox

# ====================================
# certificates
# see https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
# ====================================

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
cp ca.crt admin.crt admin.key out/jumpbox

# ====================================
# kubernetes configuration files
# see https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md
# ====================================

# download and install kubectl

wget -q https://storage.googleapis.com/kubernetes-release/release/v1.28.3/bin/linux/arm64/kubectl
chmod +x kubectl
cp kubectl /usr/local/bin/
kubectl version --client

# kubelet configuration files 

for host in node-0 node-1; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-credentials system:node:${host} \
    --client-certificate=${host}.crt \
    --client-key=${host}.key \
    --embed-certs=true \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${host} \
    --kubeconfig=${host}.kubeconfig

  kubectl config use-context default \
    --kubeconfig=${host}.kubeconfig
done

# kube-proxy configuration file

kubectl config set-cluster kubernetes-the-hard-way \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=https://server.kubernetes.local:6443 \
--kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
--client-certificate=kube-proxy.crt \
--client-key=kube-proxy.key \
--embed-certs=true \
--kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
--cluster=kubernetes-the-hard-way \
--user=system:kube-proxy \
--kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default \
--kubeconfig=kube-proxy.kubeconfig

# kube-controller-manager configuration file

kubectl config set-cluster kubernetes-the-hard-way \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=https://server.kubernetes.local:6443 \
--kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
--client-certificate=kube-controller-manager.crt \
--client-key=kube-controller-manager.key \
--embed-certs=true \
--kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
--cluster=kubernetes-the-hard-way \
--user=system:kube-controller-manager \
--kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default \
--kubeconfig=kube-controller-manager.kubeconfig

# kube-scheduler configuration file

kubectl config set-cluster kubernetes-the-hard-way \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=https://server.kubernetes.local:6443 \
--kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
--client-certificate=kube-scheduler.crt \
--client-key=kube-scheduler.key \
--embed-certs=true \
--kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
--cluster=kubernetes-the-hard-way \
--user=system:kube-scheduler \
--kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default \
--kubeconfig=kube-scheduler.kubeconfig

# admin user configuration file

kubectl config set-cluster kubernetes-the-hard-way \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=https://127.0.0.1:6443 \
--kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
--client-certificate=admin.crt \
--client-key=admin.key \
--embed-certs=true \
--kubeconfig=admin.kubeconfig

kubectl config set-context default \
--cluster=kubernetes-the-hard-way \
--user=admin \
--kubeconfig=admin.kubeconfig

kubectl config use-context default \
--kubeconfig=admin.kubeconfig

cp kube-proxy.kubeconfig node-0.kubeconfig out/node-0
cp kube-proxy.kubeconfig node-1.kubeconfig out/node-1
cp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig out/server

# ====================================
# data encryption configuration
# see https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/06-data-encryption-keys.md
# ====================================

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml << EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

cp encryption-config.yaml out/server
