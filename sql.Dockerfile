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
    awesome_print \
    mysql2 \
    sinatra \
    sinatra-contrib

EXPOSE 5001

# Create logs directory
RUN mkdir -p /home/dev/logs

CMD ["bash", "-c", "ruby /home/dev/stream_tools/server/SQLService.rb 2>&1 | tee /home/dev/logs/sql_service.log"]
