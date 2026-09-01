# frozen_string_literal: true

module DiscourseWorkflows
  module CredentialTypes
    class BasicAuth
      class << self
        def identifier
          "basic_auth"
        end

        def display_name
          "Basic Auth"
        end

        def property_schema
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
end
