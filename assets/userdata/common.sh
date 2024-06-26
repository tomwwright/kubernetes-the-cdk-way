# install dependencies

apt update
apt install -y unzip

# install aws cli

wget https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip
unzip awscli-exe-linux-aarch64.zip
./aws/install
aws --version

# download assets

mkdir -p assets
aws s3 cp --recursive s3://$bucket/$host assets
cd assets

# set up hostname and hosts file

hostnamectl hostname $host
sed -i "s/^127.0.1.1.*/127.0.1.1\t$host.kubernetes.local $host/" /etc/hosts
cat hosts >> /etc/hosts
