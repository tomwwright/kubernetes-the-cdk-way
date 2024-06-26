FROM alpine
WORKDIR /build

RUN apk add \
git \
openssl \
bash \
envsubst

RUN mkdir -p out out/server out/node-0 out/node-1 out/jumpbox

RUN git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git

COPY prepare-assets.sh machines.txt .
RUN ./prepare-assets.sh

COPY smoke-test.sh out/jumpbox

RUN chmod -R 0777 /build/out 

CMD ["cp", "-r", "/build/out/.", "/asset-output"]




