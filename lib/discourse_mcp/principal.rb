# frozen_string_literal: true

module DiscourseMcp
  class Principal
    attr_reader :user_id,
                :oauth_client_id,
                :authorization_id,
                :access_token_id,
                :profile_id,
                :scopes

    def initialize(token)
      @user_id = token.user_id
      @oauth_client_id = token.mcp_oauth_client_id
      @authorization_id = token.mcp_oauth_authorization_id
      @access_token_id = token.id
      @profile_id = token.mcp_server_profile_id
      @scopes = token.scopes.to_set.freeze
    end

    def user
      loaded = User.find_by(id: user_id)
      return if loaded.blank? || !loaded.active? || loaded.suspended? || loaded.staged?

      loaded
    end

    def guardian
      current_user = user
      raise Discourse::InvalidAccess if current_user.blank?

      current_user.guardian
    end

    def profile
      McpServerProfile.find(profile_id)
    end

    def client
      McpOauthClient.find(oauth_client_id)
    end

    def authorization
      McpOauthAuthorization.find(authorization_id)
    end

    def has_scopes?(required)
      Array(required).all? { |scope| scopes.include?(scope.to_s) }
    end
  end
end
