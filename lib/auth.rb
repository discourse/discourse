# frozen_string_literal: true

module Auth
  LOGIN_METHOD_OAUTH = "oauth"
  LOGIN_METHOD_LOCAL = "local"
end

require "auth/auth_provider"
require "auth/result"
require "auth/authenticator"
require "auth/managed_authenticator"
require "auth/facebook_authenticator"
require "auth/github_authenticator"
require "auth/twitter_authenticator"
require "auth/linkedin_oidc_authenticator"
require "auth/google_oauth2_authenticator"
require "auth/discord_authenticator"
