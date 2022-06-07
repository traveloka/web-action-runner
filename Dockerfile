FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx
FROM --platform=$BUILDPLATFORM ubuntu:focal AS volta
COPY --link --from=xx / /

RUN apt-get update -q \
 && apt-get install -y -q curl clang lld \
 && curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path --profile minimal
ENV PATH=$PATH:/root/.cargo/bin/

ARG VOLTA_VERSION=1.0.8
RUN curl -sL https://github.com/volta-cli/volta/archive/refs/tags/v${VOLTA_VERSION}.tar.gz | tar -xz \
 && cd volta-${VOLTA_VERSION} \
 && cargo fetch

ARG TARGETPLATFORM
RUN rustup target add $(xx-info march)-unknown-linux-gnu \
 && xx-clang --setup-target-triple \
 && DEBIAN_FRONTEND=noninteractive xx-apt-get install -y pkg-config libssl-dev libc6-dev

RUN cd volta-${VOLTA_VERSION} \
 && export CARGO_TARGET_$(xx-info march | tr '[:lower:]' '[:upper:]')_UNKNOWN_LINUX_GNU_LINKER=$(xx-info)-clang \
 && export CARGO_TARGET_$(xx-info march | tr '[:lower:]' '[:upper:]')_UNKNOWN_LINU_GNU_RUSTFLAGS="" \
 && export CC_$(xx-info march)_unknown_linux_gnu=$(xx-info)-clang \
 && PKG_CONFIG_ALLOW_CROSS=1 cargo build --release --target $(xx-info march)-unknown-linux-gnu \
 && mkdir /.volta \
 && ls target/ \
 && mv target/release/$(xx-info march)-unknown-linux-gnu/* /.volta

FROM summerwind/actions-runner:latest as main

# install docker cli and google-chrome
RUN true \
 && echo "deb https://download.docker.com/linux/ubuntu focal stable" | sudo tee /etc/apt/sources.list.d/docker.list \
 && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list \
 && curl -sL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
 && curl -sL https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - \
 && sudo apt update -q \
 && sudo apt upgrade -q -y \
 && sudo apt install -q -y docker-ce-cli --no-install-recommends

# install aws cli
RUN cd /tmp \
 && curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
 && unzip awscliv2.zip \
 && sudo ./aws/install \
 && rm -rf aws awscliv2.zip

# install golang
env PATH="$HOME/.gobrew/current/bin:$HOME/.gobrew/bin:$PATH"
RUN curl -sLk https://git.io/gobrew | sh - \
 && gobrew install 1.18

# install volta
env VOLTA_HOME="$HOME/.volta"
env PATH="$PATH:$VOLTA_HOME/bin"
COPY --from=volta --chown=1000:1000 /.volta /home/runner/.volta
RUN volta install node@16 && volta install yarn

# ecr login
RUN arch=$(test $(uname -m) = "aarch64" && echo arm64 || echo amd64) \
 && sudo curl -L -o /usr/bin/docker-credential-ecr-login https://amazon-ecr-credential-helper-releases.s3.us-east-2.amazonaws.com/0.6.0/linux-${arch}/docker-credential-ecr-login \
 && sudo chmod +x /usr/bin/docker-credential-ecr-login \
 && mkdir -p $HOME/.docker \
 && echo '{"credsStore": "ecr-login"}' > $HOME/.docker/config.json

# update PATH
RUN sudo sed -i "/^PATH=/c\PATH=$PATH" /etc/environment


## Perftest Image
FROM main as perftest
RUN sudo apt install -q -y google-chrome-stable --no-install-recommends
