#!/bin/bash

set -xe

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
