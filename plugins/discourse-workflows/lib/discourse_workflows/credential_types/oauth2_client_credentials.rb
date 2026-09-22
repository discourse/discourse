# frozen_string_literal: true

module DiscourseWorkflows
  module CredentialTypes
    class Oauth2ClientCredentials
      def self.identifier
        "oauth2_client_credentials"
      end

      def self.display_name
        I18n.t("discourse_workflows.oauth2.display_name")
      end

      def self.setup_key
        "discourse_workflows.oauth2.setup"
      end

      def self.ui_metadata
        { i18n_scope: "oauth2" }
      end

      def self.property_schema
        {
          client_id: {
            type: :string,
            required: true,
            no_data_expression: true,
          },
          client_secret: {
            type: :string,
            required: true,
            no_data_expression: true,
            ui: {
              control: :password,
            },
          },
          token_url: {
            type: :string,
            required: true,
            no_data_expression: true,
          },
          api_origin: {
            type: :string,
            required: true,
            no_data_expression: true,
          },
          revoke_url: {
            type: :string,
            required: false,
            no_data_expression: true,
            ui: {
              advanced: true,
            },
          },
          token_lifetime: {
            type: :string,
            required: false,
            no_data_expression: true,
            ui: {
              advanced: true,
            },
          },
          scope: {
            type: :string,
            required: false,
            no_data_expression: true,
            ui: {
              advanced: true,
            },
          },
          token_auth_method: {
            type: :options,
            required: false,
            default: "request_body",
            no_data_expression: true,
            ui: {
              advanced: true,
            },
            options: [
              { value: "request_body", label_key: "discourse_workflows.oauth2.request_body" },
              { value: "http_basic", label_key: "discourse_workflows.oauth2.http_basic" },
            ],
          },
        }
      end
    end
  end
end
