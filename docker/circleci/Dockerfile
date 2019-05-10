FROM alpine:3.9

MAINTAINER SataQiu <1527062125@qq.com>

RUN apk add --no-cache bash git curl jq

Run apk add --no-cache nodejs-current-npm && \
    npm install -g markdown-spellcheck

RUN apk add --no-cache ruby ruby-dev ruby-rdoc && \
    gem install mdl

