# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class Authenticator
        def self.apply(config, headers)
          auth_mode = config.fetch("authentication") { "none" }
          return if auth_mode == "none"

          credential = fetch_credential(config["credential_id"], auth_mode)
          cred_data = credential.decrypted_data

          case auth_mode
          when "basic_auth"
            apply_basic_auth(headers, cred_data)
          when "bearer_token"
            apply_bearer_token(headers, cred_data)
          end
        end

        def self.fetch_credential(credential_id, auth_mode)
          if credential_id.blank?
            raise ArgumentError, "credential_id is required for authentication mode '#{auth_mode}'"
          end
          DiscourseWorkflows::Credential.find(credential_id)
        end

        def self.apply_basic_auth(headers, cred_data)
          user = ExpressionResolver.resolve(cred_data["user"])
          password = ExpressionResolver.resolve(cred_data["password"])
          headers["Authorization"] = "Basic #{Base64.strict_encode64("#{user}:#{password}")}"
        end

        def self.apply_bearer_token(headers, cred_data)
          token = ExpressionResolver.resolve(cred_data["token"])
          headers["Authorization"] = "Bearer #{token}"
        end

        private_class_method :fetch_credential, :apply_basic_auth, :apply_bearer_token
      end
    end
  end
end
