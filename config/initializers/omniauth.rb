require 'openid/store/filesystem'
require 'openssl'
module OpenSSL
  module SSL
    remove_const :VERIFY_PEER
  end
end

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :open_id, :store => OpenID::Store::Filesystem.new('/tmp'), :name => 'google', :identifier => 'https://www.google.com/accounts/o8/id', :require => 'omniauth-openid' 
  provider :open_id, :store => OpenID::Store::Filesystem.new('/tmp'), :name => 'yahoo', :identifier => 'https://me.yahoo.com', :require => 'omniauth-openid' 
  provider :facebook, SiteSetting.facebook_app_id, SiteSetting.facebook_app_secret, :scope => "email"
  provider :twitter, SiteSetting.twitter_consumer_key , SiteSetting.twitter_consumer_secret
end