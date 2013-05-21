require 'openssl'
require 'openid_redis_store'

# if you need to test this and are having ssl issues see:
#  http://stackoverflow.com/questions/6756460/openssl-error-using-omniauth-specified-ssl-path-but-didnt-work

Rails.application.config.middleware.use OmniAuth::Builder do

  provider :open_id,
           :store => OpenID::Store::Redis.new($redis),
           :name => 'google',
           :identifier => 'https://www.google.com/accounts/o8/id',
           :require => 'omniauth-openid'

  provider :open_id,
           :store => OpenID::Store::Redis.new($redis),
           :name => 'yahoo',
           :identifier => 'https://me.yahoo.com',
           :require => 'omniauth-openid'

  # lambda is required for proper multisite support, 
  #  without it subdomains will not function correctly 
  provider :facebook,
           :setup => lambda { |env|
              strategy = env['omniauth.strategy']
              strategy.options[:client_id] = SiteSetting.facebook_app_id
              strategy.options[:client_secret] = SiteSetting.facebook_app_secret
           },
           :scope => "email"

  provider :twitter,
           :setup => lambda { |env|
              strategy = env['omniauth.strategy']
              strategy.options[:consumer_key] = SiteSetting.twitter_consumer_key
              strategy.options[:consumer_secret] = SiteSetting.twitter_consumer_secret
           }

  provider :github,
           :setup => lambda { |env|
              strategy = env['omniauth.strategy']
              strategy.options[:client_id] = SiteSetting.github_client_id
              strategy.options[:client_secret] = SiteSetting.github_client_secret
           }

  provider :browser_id,
           :name => 'persona'

  provider :cas,
           :host => SiteSetting.cas_hostname

end
