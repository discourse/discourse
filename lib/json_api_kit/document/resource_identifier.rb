# frozen_string_literal: true

module JsonApiKit
  class Document
    class ResourceIdentifier
      def initialize(record, glossary:, meta: {})
        @record = record
        @glossary = glossary
        @meta = meta
      end

      def to_h = { type: glossary.member_type(record.type), id: record.id, meta: }.compact_blank

      private

      attr_reader :record, :glossary, :meta
    end
  end
end
