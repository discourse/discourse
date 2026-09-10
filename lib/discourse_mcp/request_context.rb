# frozen_string_literal: true

module DiscourseMcp
  class RequestContext
    attr_reader :user_id, :oauth_client_id, :authorization_id, :access_token_id, :scopes

    def initialize(token)
      @user_id = token.user_id
      @oauth_client_id = token.mcp_oauth_client_id
      @authorization_id = token.mcp_oauth_authorization_id
      @access_token_id = token.id
      @scopes = token.scopes.to_set.freeze
    end

    def user
      return @user if defined?(@user)

      @user = User.find_by(id: user_id)
      @user = nil if @user.blank? || !@user.active? || @user.suspended? || @user.staged?

      @user
    end

    def guardian
      return @guardian if defined?(@guardian)

      current_user = user
      raise Discourse::InvalidAccess if current_user.blank?

      @guardian = current_user.guardian
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
