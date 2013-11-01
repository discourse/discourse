class Auth::HerokuAuthenticator < Auth::Authenticator

  def name
    "heroku"
  end

  def after_authenticate(auth_token)
    # no-op, handled by heroku_session_controller and heroku_session
  end

  def after_create_account(user, auth)
    # no-op, handled by heroku_session_controller and heroku_session
  end

  def register_middleware(omniauth)
    omniauth.provider :heroku,
       :setup => lambda { |env|
          strategy = env['omniauth.strategy']
          strategy.options[:client_id] = ENV['HEROKU_OAUTH_ID']
          strategy.options[:client_secret] = ENV['HEROKU_OAUTH_SECRET']
       },
       :scope => "identity"
  end

end