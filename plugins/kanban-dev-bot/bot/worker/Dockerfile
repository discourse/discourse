FROM discourse/discourse_dev:20260812-0036
USER root
RUN npm install --prefix /opt/codex node@24.22.0 @openai/codex && ln -sf /opt/codex/node_modules/node/bin/node /usr/local/bin/node && ln -sf /opt/codex/node_modules/.bin/codex /usr/local/bin/codex
ENV PATH="/usr/local/bin:${PATH}" BUNDLE_PATH=/opt/bundle
COPY template /opt/template
WORKDIR /opt/template
RUN bundle install --jobs 4 && pnpm install --frozen-lockfile && chown -R discourse:discourse /opt/bundle /opt/template /home/discourse
COPY worker /opt/bot
RUN chmod +x /opt/bot/*.sh
WORKDIR /workspace/discourse
ENTRYPOINT ["/opt/bot/boot.sh"]
