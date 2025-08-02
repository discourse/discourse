# frozen_string_literal: true

# Not fussed setting secret_token anymore, that is only required for
# backwards support of "seamless" upgrade from Rails 3.
# Discourse has shipped Rails 3 for a very long time.
Discourse::Application.config.secret_key_base = GlobalSetting.safe_secret_key_base
