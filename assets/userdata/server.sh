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
