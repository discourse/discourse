# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Update < Body
        def initialize(document, resource:, id:)
          super(document, resource:)
          @id = id
        end

        private

        attr_reader :id

        def contract
          @contract ||= Contract::Update.new(document, type: glossary.member_type(type), id:)
        end

        def existing_values = edition.existing_values(resource:, id:)
      end
    end
  end
end
