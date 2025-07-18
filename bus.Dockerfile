FROM ubuntu:latest
COPY . /home/dev
WORKDIR /home/dev

RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    ruby-full \
    mariadb-server \
    sudo \
    libcurl4-openssl-dev \
    libapr1-dev \
    libaprutil1-dev \
    apache2-dev \
    build-essential \
    libyaml-dev \
    libffi-dev \
    libssl-dev \
    zlib1g-dev \
    libmariadb-dev \
    libmariadb-dev-compat \
    pkg-config \
    ca-certificates \
    gnupg

RUN gem update && gem install bundler \
    eventmachine \
    absolute_time \
    awesome_print \
    websocket-eventmachine-server

EXPOSE 5000

CMD ["bash", "-c", "ruby", "/home/dev/stream_tools/server/BUS.rb  2>&1 | tee /home/dev/logs/bus_service.log"]