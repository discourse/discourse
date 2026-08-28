# frozen_string_literal: true

module DiscourseMcp
  class AuthorizationStatus
    def self.for(authorizations, scopes_by_authorization_id: {})
      authorizations = Array(authorizations)
      return {} if authorizations.empty?

      eligible_scopes_by_user_id = Access.eligible_scopes_by_user(authorizations.map(&:user))
      requirements = consent_requirements

      authorizations.to_h do |authorization|
        required_scopes =
          scopes_by_authorization_id.fetch(authorization.id) { authorization.scopes }
        status =
          new(
            authorization,
            eligible_scopes: eligible_scopes_by_user_id.fetch(authorization.user_id, []),
            consent_required_at:
              consent_required_at(requirements, required_scopes: required_scopes),
            required_scopes: required_scopes,
          ).status
        [authorization.id, status]
      end
    end

    def self.consent_requirements
      McpPrimitive
        .where.not(consent_required_at: nil)
        .filter_map do |policy|
          primitive = DiscourseMcp.registry.find(policy.kind, policy.identifier)
          [primitive.required_scopes, policy.consent_required_at] if primitive.present?
        end
    end

    def self.consent_required_at(consent_requirements, required_scopes:)
      consent_requirements
        .filter_map do |scopes, required_at|
          required_at if scopes.empty? || (scopes - required_scopes).empty?
        end
        .max
    end

    private_class_method :consent_requirements, :consent_required_at

    def initialize(authorization, eligible_scopes:, consent_required_at:, required_scopes:)
      @authorization = authorization
      @eligible_scopes = eligible_scopes
      @consent_required_at = consent_required_at
      @required_scopes = required_scopes
    end

    def status
      return "revoked" if authorization.status == "revoked" || authorization.revoked_at.present?
      return "consent_required" if authorization.status == "consent_required"
      return "server_disabled" if !SiteSetting.mcp_server_enabled
      return "user_unavailable" if !Access.user_available?(authorization.user)
      return "client_blocked" if authorization.client.blocked?
      return "client_not_approved" if !authorization.client.approved?
      if authorization.client_metadata_hash != authorization.client.metadata_hash ||
           !authorization.consent_current?(consent_required_at: consent_required_at)
        return "consent_required"
      end
      return "access_removed" if (required_scopes - eligible_scopes).present?

      "active"
    end

    private

    attr_reader :authorization, :eligible_scopes, :consent_required_at, :required_scopes
  end
end
