#!/bin/bash

set -xe

# install dependencies

apt update
apt install unzip

# install aws cli

wget https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip
unzip awscli-exe-linux-aarch64.zip
./aws/install
aws --version

# download assets

bucket=$1
mkdir -p assets
aws s3 cp --recursive s3://$bucket/server assets

# set up hostname and hosts file

hostnamectl hostname server
sed -i 's/^127.0.1.1.*/127.0.1.1\tserver.kubernetes.local server/' /etc/hosts
cat assets/hosts >> /etc/hosts

# install and bootstrap etcd

wget https://github.com/etcd-io/etcd/releases/download/v3.4.27/etcd-v3.4.27-linux-arm64.tar.gz
tar -xvf etcd-v3.4.27-linux-arm64.tar.gz
mv etcd-v3.4.27-linux-arm64/etcd* /usr/local/bin/

mkdir -p /etc/etcd /var/lib/etcd
chmod 700 /var/lib/etcd
cp assets/ca.crt assets/kube-api-server.key assets/kube-api-server.crt /etc/etcd/

mv assets/etcd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd

etcdctl member list


