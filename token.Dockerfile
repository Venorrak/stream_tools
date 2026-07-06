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
    gnupg \
    tmux

RUN gem update && gem install bundler \
    awesome_print \
    sinatra \
    sinatra-contrib \
    faraday \
    eventmachine \
    faye-websocket \
    openssl

EXPOSE 5002

# Create logs directory
RUN mkdir -p /home/dev/logs

# CMD ["bash", "-c", "ruby /home/dev/stream_tools/server/TokenService.rb 2>&1 | tee /home/dev/logs/token_service.log"]
CMD ["tail", "-f", "/dev/null"]
