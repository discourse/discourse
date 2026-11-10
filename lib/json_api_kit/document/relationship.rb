# frozen_string_literal: true

module JsonApiKit
  class Document
    class Relationship < Collection
      def self.input_class = Request::Input::Relationship

      private

      def representation(record, meta:)
        ResourceIdentifier.new(record, glossary: client.glossary, meta:)
      end
    end
  end
end
