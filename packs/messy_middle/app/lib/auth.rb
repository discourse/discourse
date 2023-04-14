# frozen_string_literal: true

module Auth
end

require_relative "auth/auth_provider"
require_relative "auth/result"
require_relative "auth/authenticator"
require_relative "auth/managed_authenticator"
require_relative "auth/facebook_authenticator"
require_relative "auth/github_authenticator"
require_relative "auth/twitter_authenticator"
require_relative "auth/google_oauth2_authenticator"
require_relative "auth/discord_authenticator"
