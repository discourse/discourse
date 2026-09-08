# frozen_string_literal: true

module DiscourseWorkflows
  module CredentialTypes
    class BearerToken
      class << self
        def identifier
          "bearer_token"
        end

        def display_name
          "Bearer Token"
        end

        def property_schema
          { token: { type: :string, required: true, ui: { control: :password } } }
        end
      end
    end
  end
end
