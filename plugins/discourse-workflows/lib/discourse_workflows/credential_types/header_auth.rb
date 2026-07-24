# frozen_string_literal: true

module DiscourseWorkflows
  module CredentialTypes
    class HeaderAuth
      def self.identifier
        "header_auth"
      end

      def self.display_name
        "Header Auth"
      end

      def self.property_schema
        {
          name: {
            type: :string,
            required: true,
          },
          value: {
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
