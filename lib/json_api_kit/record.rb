# frozen_string_literal: true

module JsonApiKit
  class Record
    Identity = Data.define(:type, :id)

    class ConflictingFilters < BadRequest
      def initialize
        super("Cannot apply different filters to the same relationship of the same resource.")
      end

      def title = "Conflicting relationship filters"

      def source = { parameter: "filter" }
    end

    delegate :record, :cursor, to: :row

    attr_reader :type, :namespace, :relationships

    def initialize(row, fields, type:, namespace: nil, relationships: {})
      @row = row
      @fields = fields
      @type = type
      @namespace = namespace
      @relationships = relationships
    end

    def id = @id ||= record.id.to_s

    def identity = @identity ||= Identity.new(type:, id:)

    def attributes = fields.attributes.values_for(record)

    def merge(other)
      self.class.new(
        row,
        fields,
        type:,
        namespace:,
        relationships: merge_relationships(other.relationships),
      )
    end

    def related_records = relationships.values.flat_map(&:records)

    private

    attr_reader :row, :fields

    def merge_relationships(other_relationships)
      other_relationships.merge(relationships) do |_name, other_linkage, linkage|
        raise ConflictingFilters unless linkage.filtered_like?(other_linkage)
        linkage
      end
    end
  end
end
