# frozen_string_literal: true

module DiscourseMcp
  class RequestContext
    attr_reader :user_id,
                :oauth_client_id,
                :authorization_id,
                :access_token_id,
                :token_scopes,
                :scopes,
                :content_policy

    # The content policy is loaded here, once, so every check in the request
    # sees the same rules.
    #
    # `token_scopes` are the scopes the token was granted. `scopes` are the ones
    # this request may use: the token's scopes minus those the content policy
    # revoked. The token, its authorization and the user's eligible scopes are
    # never changed, so lifting the restriction restores them on the next request.
    def initialize(token, content_policy: ContentPolicy.load)
      @user_id = token.user_id
      @oauth_client_id = token.mcp_oauth_client_id
      @authorization_id = token.mcp_oauth_authorization_id
      @access_token_id = token.id
      @content_policy = content_policy
      @token_scopes = token.scopes.to_set.freeze
      @scopes = (@token_scopes - content_policy.revoked_scopes).freeze
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

    # The checker for text and uploads an agent writes in this request. It
    # remembers the granted uploads the request used.
    #
    # @returns [AuthoredText]
    def authored_text
      @authored_text ||= AuthoredText.new(self)
    end

    def authorization
      McpOauthAuthorization.find(authorization_id)
    end

    # Raises unless this request may use every required scope.
    #
    # A scope the content policy revoked can't be regained by authorizing again,
    # so it never gets a WWW-Authenticate challenge. With `not_found`, the caller
    # gets its own not-found error instead, so restricted content answers exactly
    # like content that doesn't exist.
    #
    # @param required [String, Array<String>]
    # @param not_found [String, nil] The caller's not-found message.
    def ensure_scopes!(required, not_found: nil)
      required = Array(required)
      return if has_scopes?(required)

      if required.any? { |scope| content_policy.revoked_scopes.include?(scope.to_s) }
        raise ToolError, not_found if not_found
        raise ContentPolicyBlocked
      end

      raise Error.new(
              "Insufficient scope",
              code: -32_001,
              http_status: 403,
              data: {
                required_scopes: required,
              },
              headers: {
                "WWW-Authenticate" =>
                  Authenticator.challenge(scope: required.join(" "), error: "insufficient_scope"),
              },
            )
    end

    def has_scopes?(required)
      Array(required).all? { |scope| scopes.include?(scope.to_s) }
    end
  end
end
