# install system dependencies

apt update
apt install -y socat conntrack ipset

# disable swap

swapoff -a

# install CLI tools

wget -q \
  https://storage.googleapis.com/kubernetes-release/release/v1.28.3/bin/linux/arm64/kubectl \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.28.0/crictl-v1.28.0-linux-arm.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.arm64
tar -xvf crictl-v1.28.0-linux-arm.tar.gz
mv runc.arm64 runc

chmod +x crictl kubectl runc 
mv crictl kubectl runc /usr/local/bin/

# configure CNI networking

mkdir -p /etc/cni/net.d /opt/cni/bin
mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/

wget -q https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-arm64-v1.3.0.tgz
tar -xvf cni-plugins-linux-arm64-v1.3.0.tgz -C /opt/cni/bin/

# configure containerd

mkdir -p containerd /etc/containerd/
mv containerd-config.toml /etc/containerd/config.toml
mv containerd.service /etc/systemd/system/

wget -q https://github.com/containerd/containerd/releases/download/v1.7.8/containerd-1.7.8-linux-arm64.tar.gz
tar -xvf containerd-1.7.8-linux-arm64.tar.gz -C containerd
mv containerd/bin/* /bin/

# configure kubelet

mkdir -p /var/lib/kubelet
mv kubelet-config.yaml /var/lib/kubelet/
mv kubelet.service /etc/systemd/system/

wget -q https://storage.googleapis.com/kubernetes-release/release/v1.28.3/bin/linux/arm64/kubelet
chmod +x kubelet
mv kubelet /usr/local/bin/

# configure kubernetes proxy

mkdir -p /var/lib/kube-proxy
mv kube-proxy-config.yaml /var/lib/kube-proxy/
mv kube-proxy.service /etc/systemd/system/

wget -q https://storage.googleapis.com/kubernetes-release/release/v1.28.3/bin/linux/arm64/kube-proxy
chmod +x kube-proxy
mv kube-proxy /usr/local/bin/

# configure worker services

sleep 10 # give control server time to complete

systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy
