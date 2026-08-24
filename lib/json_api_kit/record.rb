# frozen_string_literal: true

module JsonApiKit
  class Record
    Identity = Data.define(:type, :id)

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
        relationships: other.relationships.merge(relationships),
      )
    end

    def related_records = relationships.values.flat_map(&:records)

    private

    attr_reader :row, :fields
  end
end
