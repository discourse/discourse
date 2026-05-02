# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class Authenticator
        def self.apply(config, headers, exec_ctx)
          auth_mode = config.fetch("authentication") { "none" }
          return if auth_mode == "none"

          cred_data = fetch_credential_data(exec_ctx, config["credential_id"], auth_mode)

          case auth_mode
          when "basic_auth"
            apply_basic_auth(headers, cred_data)
          when "bearer_token"
            apply_bearer_token(headers, cred_data)
          end
        end

        def self.fetch_credential_data(exec_ctx, credential_id, auth_mode)
          if credential_id.blank?
            raise ArgumentError, "credential_id is required for authentication mode '#{auth_mode}'"
          end
          if exec_ctx.nil?
            raise ArgumentError, "exec_ctx is required for authentication mode '#{auth_mode}'"
          end

          exec_ctx.get_credential(credential_id)
        end

        def self.apply_basic_auth(headers, cred_data)
          user = cred_data["user"]
          password = cred_data["password"]
          headers["Authorization"] = "Basic #{Base64.strict_encode64("#{user}:#{password}")}"
        end

        def self.apply_bearer_token(headers, cred_data)
          token = cred_data["token"]
          headers["Authorization"] = "Bearer #{token}"
        end

        private_class_method :fetch_credential_data, :apply_basic_auth, :apply_bearer_token
      end
    end
  end
end
