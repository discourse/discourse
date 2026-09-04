# frozen_string_literal: true

module DiscourseWorkflows
  module CredentialTypes
    class Oauth2ClientCredentials
      def self.identifier
        "oauth2_client_credentials"
      end

      def self.display_name
        "OAuth 2.0 client credentials"
      end

      def self.property_schema
        {
          token_url: {
            type: :string,
            required: true,
            no_data_expression: true,
          },
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
          client_authentication: {
            type: :options,
            options: %w[request_body basic_auth],
            default: "request_body",
            no_data_expression: true,
          },
          scope: {
            type: :string,
            required: false,
            no_data_expression: true,
          },
        }
      end
    end
  end
end
