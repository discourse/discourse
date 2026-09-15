# frozen_string_literal: true

module JsonApiKit
  class Document
    class ResourceObject
      delegate :id, to: :record, private: true
      delegate :glossary, :urls, to: :client, private: true

      def initialize(record, client:, fieldsets:, meta: {})
        @record = record
        @client = client
        @fieldsets = fieldsets
        @meta = meta
      end

      def to_h = { type:, id:, attributes:, relationships:, links:, meta: }.compact_blank

      private

      attr_reader :record, :client, :fieldsets, :meta

      def type = glossary.member_type(record.type)

      def relationship(value) = Name::Relationship.new(value:, type: record.type)

      def member_value(name) = glossary.member_name(name).value

      def attributes
        fieldsets.keep(type, glossary.member_attributes(record.attributes).transform_keys(&:value))
      end

      def relationships
        record.relationships.to_h do |name, linkage|
          member = member_value(relationship(name))
          [member, RelationshipObject.new(linkage, client:, owner: record, name: member).to_h]
        end
      end

      def links = { self: urls.for(record).to_s }
    end
  end
end
