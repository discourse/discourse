# frozen_string_literal: true

module JsonApiKit
  class Document
    class Relationship < Collection
      def self.input_class = Request::Input::Relationship

      private

      def data
        contents.primary.map do |record|
          ResourceIdentifier.new(record, glossary: client.glossary, meta: page_meta(record)).to_h
        end
      end
    end
  end
end
