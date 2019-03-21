class Auth::FacebookAuthenticator < Auth::ManagedAuthenticator
  AVATAR_SIZE ||= 480

  def name
    'facebook'
  end

  def enabled?
    SiteSetting.enable_facebook_logins
  end

  def register_middleware(omniauth)
    setup =
      lambda do |env|
        strategy = env['omniauth.strategy']
        strategy.options[:client_id] = SiteSetting.facebook_app_id
        strategy.options[:client_secret] = SiteSetting.facebook_app_secret
        strategy.options[:info_fields] = 'name,first_name,last_name,email'
        strategy.options[:image_size] = {
          width: AVATAR_SIZE, height: AVATAR_SIZE
        }
        strategy.options[:secure_image_url] = true
      end
    omniauth.provider :facebook, setup: setup, scope: 'email'
  end
end
