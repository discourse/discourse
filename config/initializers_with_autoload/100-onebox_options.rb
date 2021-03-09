# frozen_string_literal: true

if Rails.env.development? && SiteSetting.port.to_i > 0
  Onebox.options = {
    twitter_client: TwitterApi,
    redirect_limit: 3,
    user_agent: "Discourse Forum Onebox v#{Discourse::VERSION::STRING}",
    allowed_ports: [80, 443, SiteSetting.port.to_i]
  }
else
  Onebox.options = {
    twitter_client: TwitterApi,
    redirect_limit: 3,
    user_agent: "Discourse Forum Onebox v#{Discourse::VERSION::STRING}"
  }
end
