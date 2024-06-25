FROM alpine

RUN apk add \
git \
openssl \
bash \
envsubst

# RUN adduser -D build
# USER build
# WORKDIR /home/build

WORKDIR /build
RUN mkdir -p out out/server out/node-0 out/node-1

RUN git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git

COPY certificates.sh .
RUN ./certificates.sh

COPY kube-configurations.sh .
RUN ./kube-configurations.sh

COPY encryption-configuration.sh encryption-config.yaml .
RUN ./encryption-configuration.sh

COPY hosts.sh machines.txt .
RUN ./hosts.sh

RUN chmod -R 0777 /build/out 

CMD ["cp", "-r", "/build/out/.", "/asset-output"]




