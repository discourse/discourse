# frozen_string_literal: true

module DiscourseWorkflows
  module CredentialTypes
    class BasicAuth
      def self.identifier
        "basic_auth"
      end

      def self.display_name
        "Basic Auth"
      end

      def self.configuration_schema
        {
          user: {
            type: :string,
            required: true,
            ui: {
              expression: true,
            },
          },
          password: {
            type: :string,
            required: true,
            ui: {
              expression: true,
              control: :password,
            },
          },
        }
      end
    end
  end
end
