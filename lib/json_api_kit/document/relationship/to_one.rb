# frozen_string_literal: true

module JsonApiKit
  class Document
    class Relationship
      class ToOne < RelatedResource
        class << self
          def input_class = Request::Input::ToOneRelationship

          def from(record, **context) = from_records(Array.wrap(record), **context)
        end

        private

        def representation(record) = ResourceIdentifier.new(record, glossary: client.glossary)
      end
    end
  end
end
