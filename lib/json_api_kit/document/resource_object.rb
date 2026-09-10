# frozen_string_literal: true

module JsonApiKit
  class Document
    class ResourceObject
      delegate :type, :id, to: :record, private: true

      def initialize(record, urls:, glossary:, meta: {})
        @record = record
        @urls = urls
        @glossary = glossary
        @meta = meta
      end

      def to_h = { type:, id:, attributes:, relationships:, links:, meta: }.compact_blank

      private

      attr_reader :record, :urls, :glossary, :meta

      def field(value) = Name::Field.new(value:, type:)

      def relationship(value) = Name::Relationship.new(value:, type:)

      def member_value(name) = glossary.member_name(name).value

      def attributes = record.attributes.transform_keys { member_value(field(it)) }

      def relationships
        record.relationships.to_h do |name, linkage|
          member = member_value(relationship(name))
          [member, RelationshipObject.new(linkage, urls:, owner: record, name: member).to_h]
        end
      end

      def links = { self: urls.for(record).to_s }
    end
  end
end
