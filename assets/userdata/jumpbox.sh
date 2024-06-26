# prepare smoke test script

chmod +x smoke-test.sh

# install kubectl

wget -q https://storage.googleapis.com/kubernetes-release/release/v1.28.3/bin/linux/arm64/kubectl
chmod +x kubectl  
mv kubectl /usr/local/bin/

# add certificate to trust

cp ca.crt /usr/local/share/ca-certificates/kubernetes.crt
update-ca-certificates

# configure kubectl

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443

kubectl config set-credentials admin \
  --client-certificate=admin.crt \
  --client-key=admin.key

kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin

kubectl config use-context kubernetes-the-hard-way

# create kubeconfig for ssm-user

mkdir -p /home/ssm-user/.kube
cp .kube/config /home/ssm-user/.kube
chmod 0777 /home/ssm-user/.kube/config

# wait for cluster then test configuration

sleep 15

kubectl version
kubectl get nodes
