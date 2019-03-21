class Auth::InstagramAuthenticator < Auth::ManagedAuthenticator
  def name
    'instagram'
  end

  def enabled?
    SiteSetting.enable_instagram_logins
  end

  def register_middleware(omniauth)
    omniauth.provider :instagram, setup: lambda do |env|
      strategy = env['omniauth.strategy']
      strategy.options[:client_id] = SiteSetting.instagram_consumer_key
      strategy.options[:client_secret] = SiteSetting.instagram_consumer_secret
    end
  end
end
