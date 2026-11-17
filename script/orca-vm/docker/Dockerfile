FROM discourse/discourse_dev:release

RUN apt-get update \
  && apt-get install -y --no-install-recommends openssh-server \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /etc/ssh/ssh_host_* \
  && env | grep -E '^(LANG|LANGUAGE|LC_ALL|LEFTHOOK|RUBY_ALLOCATOR)=' >> /etc/environment

RUN npm install -g @openai/codex

USER discourse
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root
RUN ln -s /home/discourse/.local/bin/claude /usr/local/bin/claude

COPY sshd_config /etc/ssh/sshd_config.d/orca.conf
COPY sshd-run /etc/service/sshd/run
COPY orca /usr/local/bin/orca
COPY bootstrap.sh /usr/local/bin/orca-discourse-bootstrap
COPY entrypoint.sh /usr/local/bin/orca-docker-ssh-entrypoint

ENTRYPOINT ["/usr/local/bin/orca-docker-ssh-entrypoint"]
