#!/bin/bash

set -xe

cp kubernetes-the-hard-way/units/etcd.service \
  kubernetes-the-hard-way/units/kube-apiserver.service \
  kubernetes-the-hard-way/units/kube-controller-manager.service \
  kubernetes-the-hard-way/units/kube-scheduler.service \
  kubernetes-the-hard-way/configs/kube-scheduler.yaml \
  kubernetes-the-hard-way/configs/kube-apiserver-to-kubelet.yaml \
  out/server