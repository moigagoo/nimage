#? stdtmpl
#proc ubuntu*(version: string,
#             labels: openarray[(string, string)] = {:}): string =
FROM ubuntu:focal
#  for label, value in labels.items:
LABEL $label="$value"
#  end for
RUN apt-get update; apt-get install -y wget xz-utils g++; \
    wget -qO- https://deb.nodesource.com/setup_13.x | bash -; \
    apt-get install -y nodejs
RUN wget https://nim-lang.org/download/nim-${version}.tar.xz; \
    tar xf nim-${version}.tar.xz; rm nim-${version}.tar.xz; \
    mv nim-${version} nim; \
    cd nim; sh build.sh; \
    rm -r c_code tests; \
    ln -s `pwd`/bin/nim /bin/nim
#end proc
#
#proc alpine*(version: string,
#             labels: openarray[(string, string)] = {:}): string =
FROM alpine:3.20
#  for label, value in labels.items:
LABEL $label="$value"
#  end for
RUN apk add --no-cache g++ curl tar xz nodejs
RUN mkdir -p /nim; \
    curl -sL "https://nim-lang.org/download/nim-${version}.tar.xz" \
    |tar xJ --strip-components=1 -C /nim; \
    cd /nim; sh build.sh; \
    rm -r c_code tests; \
    ln -s `pwd`/bin/nim /bin/nim
#end proc
