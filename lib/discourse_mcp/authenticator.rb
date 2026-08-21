# frozen_string_literal: true

module DiscourseMcp
  class Authenticator
    Challenge = Data.define(:status, :header)

    def initialize(request)
      @request = request
    end

    def authenticate!
      scheme, raw_token = request.authorization.to_s.split(" ", 2)
      raise AuthenticationError if scheme.blank? && raw_token.blank?
      if !scheme.to_s.casecmp?("Bearer") || raw_token.blank?
        raise AuthenticationError.new("invalid_token")
      end

      token = McpOauthAccessToken.usable.find_by(token_hash: McpOauthAccessToken.digest(raw_token))
      raise AuthenticationError.new("invalid_token") if token.blank?

      authorization = token.authorization
      profile = token.profile
      client = token.client
      valid =
        token.resource == DiscourseMcp.resource_url && authorization.active? &&
          token.grant_version == authorization.grant_version &&
          (token.scopes - authorization.scopes).empty? &&
          (token.scopes - profile.allowed_scopes).empty? &&
          authorization.consent_revision >= profile.consent_revision &&
          authorization.client_metadata_hash == client.metadata_hash && client.approved? &&
          profile.available? && profile.user_allowed?(token.user)
      raise AuthenticationError.new("invalid_token") if !valid

      token.touch_last_used!
      Principal.new(token)
    end

    def self.challenge(scope: nil, error: nil)
      values = [%(resource_metadata="#{DiscourseMcp.protected_resource_metadata_url}")]
      values << %(scope="#{scope}") if scope.present?
      values << %(error="#{error}") if error.present?
      "Bearer #{values.join(", ")}"
    end

    private

    attr_reader :request
  end
end
