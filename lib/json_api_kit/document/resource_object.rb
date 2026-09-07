# frozen_string_literal: true

module JsonApiKit
  class Document
    class ResourceObject
      delegate :type, :id, :attributes, to: :record, private: true

      def initialize(record, urls:, meta: {})
        @record = record
        @urls = urls
        @meta = meta
      end

      def to_h = { type:, id:, attributes:, relationships:, links:, meta: }.compact_blank

      private

      attr_reader :record, :urls, :meta

      def relationships
        record.relationships.to_h do |name, linkage|
          [name, RelationshipObject.new(linkage, urls:, owner: record, name:).to_h]
        end
      end

      def links = { self: urls.for(record).to_s }
    end
  end
end
