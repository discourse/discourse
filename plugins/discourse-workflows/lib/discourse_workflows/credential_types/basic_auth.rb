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

      def self.property_schema
        {
          user: {
            type: :string,
            required: true,
          },
          password: {
            type: :string,
            required: true,
            ui: {
              control: :password,
            },
          },
        }
      end
    end
  end
end
