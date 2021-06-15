FROM golang:1.15 as build

ARG TAG=v1.10.3

RUN apt-get update && apt-get install -y make gcc libc6-dev git && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ethereum/go-ethereum.git \
    && cd /go/go-ethereum \
    && git checkout $TAG \
    && env GO111MODULE=on go run build/ci.go install ./cmd/clef

RUN mkdir -p /out/usr/local/bin
RUN cp /go/go-ethereum/build/bin/clef /out/usr/local/bin/clef
COPY packaging/rules.js /out/app/config/rules.js
COPY packaging/4byte.json /out/app/config/4byte.json
COPY packaging/docker/entrypoint.sh /out/entrypoint.sh

#RUN chown -R nobody:nogroup /out

FROM debian:10.2-slim as runtime
COPY --from=build /out /

EXPOSE 8550
#USER nobody
WORKDIR /app
VOLUME /app/data

ENTRYPOINT ["/entrypoint.sh"]
