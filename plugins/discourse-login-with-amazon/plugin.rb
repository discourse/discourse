# frozen_string_literal: true

# name: discourse-login-with-amazon
# about: Enables login authentication via Login with Amazon
# meta_topic_id: 117564
# version: 0.0.1
# authors: Alan Tan
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-login-with-amazon

enabled_site_setting :enable_login_with_amazon

register_svg_icon "fab-amazon"

require_relative "lib/auth/login_with_amazon_authenticator"
require_relative "lib/validators/enable_login_with_amazon_validator"
require_relative "lib/omniauth/strategies/amazon"

auth_provider authenticator: Auth::LoginWithAmazonAuthenticator.new, icon: "fab-amazon"
