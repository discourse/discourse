# frozen_string_literal: true

module DiscourseWorkflows
  class Webhook::Action::AuthenticateNode < Service::ActionBase
    AUTHENTICATED = :authenticated
    CHALLENGE = :challenge
    DENIED = :denied
    MISCONFIGURED = :misconfigured

    BASIC_AUTH = "basic_auth"
    BEARER_AUTH = "bearer_auth"
    HEADER_AUTH = "header_auth"
    NO_AUTH = "none"

    SUPPORTED_AUTH_MODES = [NO_AUTH, BASIC_AUTH, BEARER_AUTH, HEADER_AUTH].freeze

    option :node
    option :params
    option :credentials, default: -> { {} }

    def call
      auth_mode = NodeData.resolved_parameters(node)["authentication"] || NO_AUTH
      return AUTHENTICATED if auth_mode == NO_AUTH

      if SUPPORTED_AUTH_MODES.exclude?(auth_mode)
        Rails.logger.warn("Unsupported webhook auth mode '#{auth_mode}' for node #{node["id"]}")
        return MISCONFIGURED
      end

      credential = lookup_credential
      return MISCONFIGURED unless credential

      case auth_mode
      when BASIC_AUTH
        authenticate_basic_auth(credential)
      when BEARER_AUTH
        authenticate_bearer_auth(credential)
      when HEADER_AUTH
        authenticate_header_auth(credential)
      end
    end

    private

    def lookup_credential
      credential_ref = NodeData.credentials(node)["auth"]
      unless credential_ref
        Rails.logger.warn("Workflow credential not configured for node #{node["id"]}")
        return nil
      end

      credential = credentials[credential_ref["id"].to_i]
      unless credential
        Rails.logger.warn("Workflow credential not found for node #{node["id"]}")
        return nil
      end

      credential
    end

    def authenticate_basic_auth(credential)
      cred_data = credential.data || {}
      expected_user = ExpressionResolver.resolve(cred_data["user"])
      expected_password = ExpressionResolver.resolve(cred_data["password"])

      return MISCONFIGURED if expected_user.blank? || expected_password.blank?

      auth_header = params.raw_authorization
      return CHALLENGE if auth_header.blank? || !auth_header.start_with?("Basic ")

      decoded = Base64.decode64(auth_header.split(" ", 2).last)
      request_user, request_password = decoded.split(":", 2)

      if secure_compare(request_user, expected_user) &&
           secure_compare(request_password, expected_password)
        AUTHENTICATED
      else
        DENIED
      end
    end

    def authenticate_bearer_auth(credential)
      cred_data = credential.data || {}
      expected_token = ExpressionResolver.resolve(cred_data["token"])

      return MISCONFIGURED if expected_token.blank?

      auth_header = params.raw_authorization.to_s
      return DENIED unless auth_header.start_with?("Bearer ")

      provided_token = auth_header.split(" ", 2).last
      secure_compare(provided_token, expected_token) ? AUTHENTICATED : DENIED
    end

    def authenticate_header_auth(credential)
      cred_data = credential.data || {}
      expected_name = ExpressionResolver.resolve(cred_data["name"])
      expected_value = ExpressionResolver.resolve(cred_data["value"])

      return MISCONFIGURED if expected_name.blank? || expected_value.blank?

      header_key = expected_name.to_s.downcase
      provided_value = (params.headers[header_key] || params.headers[header_key.to_sym]).to_s
      secure_compare(provided_value, expected_value) ? AUTHENTICATED : DENIED
    end

    def secure_compare(a, b)
      ActiveSupport::SecurityUtils.secure_compare(a.to_s, b.to_s)
    end
  end
end
