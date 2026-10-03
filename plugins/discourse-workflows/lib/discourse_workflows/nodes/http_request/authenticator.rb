# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class Authenticator
        extend NodeErrorHandling

        # RFC 7230 header field-name
        HEADER_NAME_PATTERN = /\A[A-Za-z0-9!#$%&'*+.^_`|~-]+\z/

        def self.apply(config, headers, exec_ctx, item_index: 0)
          auth_mode = config.fetch("authentication") { "none" }
          return [] if auth_mode == "none"

          if exec_ctx.nil?
            raise_node_error!(
              I18n.t("discourse_workflows.errors.http_request.exec_ctx_required", mode: auth_mode),
            )
          end

          credential_type = Registry.find_credential_type(auth_mode)
          raise Discourse::InvalidAccess unless credential_type

          if auth_mode == "oauth2_client_credentials"
            credential = exec_ctx.get_credential("auth")
            raise Discourse::InvalidAccess unless credential.credential_type == auth_mode
            headers["Authorization"] = Oauth2Connection.new(credential).authorization_header(
              config["url"],
            )
            return ["Authorization"]
          end

          cred_data = exec_ctx.get_credentials("auth", item_index)

          case auth_mode
          when "basic_auth"
            apply_basic_auth(headers, cred_data)
          when "bearer_token"
            apply_bearer_token(headers, cred_data)
          when "header_auth"
            apply_header_auth(headers, cred_data)
          else
            raise Discourse::InvalidAccess
          end
        end

        def self.apply_basic_auth(headers, cred_data)
          user = cred_data["user"]
          password = cred_data["password"]
          headers["Authorization"] = "Basic #{Base64.strict_encode64("#{user}:#{password}")}"
          ["Authorization"]
        end

        def self.apply_bearer_token(headers, cred_data)
          token = cred_data["token"]
          headers["Authorization"] = "Bearer #{token}"
          ["Authorization"]
        end

        def self.apply_header_auth(headers, cred_data)
          name = cred_data["name"].to_s
          unless name.match?(HEADER_NAME_PATTERN)
            raise_node_error!(I18n.t("discourse_workflows.errors.http_request.header_name_invalid"))
          end
          headers[name] = cred_data["value"]
          [name]
        end

        private_class_method :apply_basic_auth, :apply_bearer_token, :apply_header_auth
      end
    end
  end
end
