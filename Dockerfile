FROM summerwind/actions-runner:latest

# install docker cli and google-chrome
RUN true \
 && echo "deb https://download.docker.com/linux/ubuntu focal stable" | sudo tee /etc/apt/sources.list.d/docker.list \
 && echo 'deb http://download.opensuse.org/repositories/home:/ungoogled_chromium/Ubuntu_Focal/ /' | sudo tee /etc/apt/sources.list.d/home-ungoogled_chromium.list \
 && curl -sL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
 && curl -sL "https://download.opensuse.org/repositories/home:/ungoogled_chromium/Ubuntu_Focal/Release.key" | sudo apt-key add - \
 && sudo apt update -q \
 && sudo apt upgrade -q -y \
 && sudo apt install -q -y docker-ce-cli ungoogled-chromium --no-install-recommends

# install aws cli
RUN cd /tmp \
 && curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
 && unzip awscliv2.zip \
 && sudo ./aws/install \
 && rm -rf aws awscliv2.zip

# install golang
ARG GOLANG_VERSION=1.18
ENV PATH="$PATH:$HOME/.gobrew/current/bin:$HOME/.gobrew/bin"
RUN curl -sLk https://git.io/gobrew | sh - \
 && gobrew install ${GOLANG_VERSION}

# install rust
ENV PATH="$PATH:$HOME/.cargo/bin"
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# build volta
ARG VOLTA_VERSION=1.0.5
ENV VOLTA_HOME="$HOME/.volta"
ENV PATH="$PATH:$VOLTA_HOME/bin"
RUN cd /tmp \
 && curl -sL https://github.com/volta-cli/volta/archive/refs/tags/v${VOLTA_VERSION}.tar.gz | tar xvz \
 && cd volta-${VOLTA_VERSION} \
 && sudo apt install -q -y libssl-dev pkg-config \
 && ./dev/unix/volta-install.sh --release \
 && cd / \
 && rm -rf /tmp/volta-${VOLTA_VERSION} $HOME/.cargo/registry/*
 
# install node
RUN volta install node@16 && volta install yarn

# ecr login
RUN arch=$(test $(uname -m) = "aarch64" && echo arm64 || echo amd64) \
 && sudo curl -L -o /usr/bin/docker-credential-ecr-login https://amazon-ecr-credential-helper-releases.s3.us-east-2.amazonaws.com/0.6.0/linux-${arch}/docker-credential-ecr-login \
 && sudo chmod +x /usr/bin/docker-credential-ecr-login \
 && mkdir -p $HOME/.docker \
 && echo '{"credsStore": "ecr-login"}' > $HOME/.docker/config.json
