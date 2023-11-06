FROM discourse/discourse_test:release

ARG github_sha

ADD prepare_base.sh /test-image/prepare_base.sh
RUN sudo -EH -u discourse /test-image/prepare_base.sh
