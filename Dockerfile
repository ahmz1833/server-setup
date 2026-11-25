# Runner image: ansible-core + this collection (from the build context, so the image tag
# matches the collection version) + its dependencies. Used for CI deploys and as
# `make docker-shell` in projects without a local Python/Ansible.
FROM python:3.12-alpine3.22

RUN apk add --no-cache openssh-client git make bash openssl rsync sshpass \
 && pip install --no-cache-dir "ansible-core>=2.16,<2.20" passlib jmespath

WORKDIR /src
COPY . /src
RUN ansible-galaxy collection build --output-path /tmp/dist \
 && ansible-galaxy collection install /tmp/dist/*.tar.gz -p /usr/share/ansible/collections \
 && rm -rf /tmp/dist /src \
 && mkdir -p /root/.ssh && chmod 700 /root/.ssh

ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections \
    ANSIBLE_HOST_KEY_CHECKING=True
WORKDIR /work
CMD ["sh"]
