require_dependency 'twitter_api'

Onebox.options = {
  twitter_client: TwitterApi,
  redirect_limit: 3,
  user_agent: "Discourse Forum Onebox v#{Discourse::VERSION::STRING}"
}
