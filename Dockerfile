FROM alpine:latest

# Install tools
RUN apk add --no-cache ansible openssh-client git

# Setup safe directory structures
RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Install heavy dependencies
RUN ansible-galaxy collection install git+https://github.com/ahmz1833/server-setup.git && \
    ansible-galaxy collection install community.docker

CMD ["sh"]
