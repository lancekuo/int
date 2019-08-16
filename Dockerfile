FROM golang:1.12 as builder

# Install dependencies
RUN apt-get update
RUN apt-get install unzip

# Install protoc
RUN go get -u github.com/bugagazavr/go-gitlab-client
RUN go get -u github.com/codegangsta/martini
RUN go get -u github.com/codegangsta/martini-contrib/render

COPY . .

RUN go build .

# TODO: optimize this docker image
FROM debian:stretch-slim

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends curl ca-certificates openssl
ENV LD_LIBRARY_PATH $TARGET_DIRECTORY/lib
ENV LIBRARY_PATH $TARGET_DIRECTORY/lib

COPY --from=builder /go/go /go
COPY --from=builder /go/config.json /config.json
COPY --from=builder /go/public /public
COPY --from=builder /go/templates /templates

EXPOSE 3000


ENTRYPOINT ["/go"]
CMD []
