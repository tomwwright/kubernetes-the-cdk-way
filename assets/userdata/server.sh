# install and bootstrap etcd

wget -q https://github.com/etcd-io/etcd/releases/download/v3.4.27/etcd-v3.4.27-linux-arm64.tar.gz
tar -xvf etcd-v3.4.27-linux-arm64.tar.gz
mv etcd-v3.4.27-linux-arm64/etcd* /usr/local/bin/

mkdir -p /etc/etcd /var/lib/etcd
chmod 700 /var/lib/etcd
cp ca.crt kube-api-server.key kube-api-server.crt /etc/etcd/

mv etcd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd

etcdctl member list

# install and bootstrap kubernetes control plane

wget -q https://storage.googleapis.com/kubernetes-release/release/v1.28.3/bin/linux/arm64/kubectl \
 https://storage.googleapis.com/kubernetes-release/release/v1.28.3/bin/linux/arm64/kube-apiserver \
 https://storage.googleapis.com/kubernetes-release/release/v1.28.3/bin/linux/arm64/kube-controller-manager \
 https://storage.googleapis.com/kubernetes-release/release/v1.28.3/bin/linux/arm64/kube-scheduler

chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl  
mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

mkdir -p /etc/kubernetes/config /var/lib/kubernetes/

mv ca.crt ca.key \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  encryption-config.yaml \
  /var/lib/kubernetes/

mv kube-apiserver.service /etc/systemd/system/kube-apiserver.service
mv kube-controller-manager.service /etc/systemd/system/
mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
mv kube-scheduler.kubeconfig /var/lib/kubernetes/
mv kube-scheduler.yaml /etc/kubernetes/config/
mv kube-scheduler.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable kube-apiserver kube-controller-manager kube-scheduler
systemctl start kube-apiserver kube-controller-manager kube-scheduler

sleep 5

kubectl cluster-info --kubeconfig admin.kubeconfig

# configure kubelet authorization

kubectl apply -f kube-apiserver-to-kubelet.yaml --kubeconfig admin.kubeconfig