# frozen_string_literal: true

module DiscourseWorkflows
  module CredentialTypes
    class BearerToken
      def self.identifier
        "bearer_token"
      end

      def self.display_name
        "Bearer Token"
      end

      def self.property_schema
        { token: { type: :string, required: true, ui: { control: :password } } }
      end
    end
  end
end
