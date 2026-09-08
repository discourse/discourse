# frozen_string_literal: true

module DiscourseWorkflows
  module CredentialTypes
    class HeaderAuth
      class << self
        def identifier
          "header_auth"
        end

        def display_name
          "Header Auth"
        end

        def property_schema
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
end
