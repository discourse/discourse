# frozen_string_literal: true

module DiscourseWorkflows
  class Webhook::Action::AuthenticateNode < Service::ActionBase
    option :node
    option :params

    def call
      config = node["configuration"] || {}
      auth_mode = config["authentication"] || "none"
      return true if auth_mode == "none"

      unless auth_mode == "basic_auth"
        Rails.logger.warn("Unsupported webhook auth mode '#{auth_mode}' for node #{node["id"]}")
        return false
      end

      authenticate_basic_auth(config)
    end

    private

    def authenticate_basic_auth(config)
      credential = DiscourseWorkflows::Credential.find_by(id: config["credential_id"])
      unless credential
        Rails.logger.warn(
          "Workflow credential not found (id=#{config["credential_id"]}) for node #{node["id"]}",
        )
        return false
      end

      cred_data =
        begin
          credential.decrypted_data
        rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError
          Rails.logger.warn(
            "Workflow credential decryption failed (id=#{config["credential_id"]}) for node #{node["id"]}",
          )
          return false
        end

      expected_user = DiscourseWorkflows::ExpressionResolver.resolve(cred_data["user"])
      expected_password = DiscourseWorkflows::ExpressionResolver.resolve(cred_data["password"])

      auth_header = params.raw_authorization
      return false unless auth_header&.start_with?("Basic ")

      decoded = Base64.decode64(auth_header.split(" ", 2).last)
      request_user, request_password = decoded.split(":", 2)

      ActiveSupport::SecurityUtils.secure_compare(request_user.to_s, expected_user.to_s) &&
        ActiveSupport::SecurityUtils.secure_compare(request_password.to_s, expected_password.to_s)
    end
  end
end
