# frozen_string_literal: true

module JsonApiKit
  class Document
    class Relationship
      class ToOne < RelatedResource
        def self.input_class = Request::Input::ToOneRelationship

        private

        def representation(record) = ResourceIdentifier.new(record, glossary: client.glossary)
      end
    end
  end
end
