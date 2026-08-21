# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Fields
      Collision = Class.new(StandardError)

      RESERVED = %w[type id].freeze

      def self.for(names, **declarations)
        return All.new(**declarations) unless names
        new(names, **declarations)
      end

      def initialize(names, attributes:, relationships:, schema:)
        @names = names
        @declared_attributes = attributes
        @declared_relationships = relationships
        @schema = schema
        verify_field_names
      end

      def attributes = Attributes.new(pick(declared_attributes), schema:)

      def relationships = Relationships.new(pick(declared_relationships))

      def columns = attributes.columns

      private

      attr_reader :names, :declared_attributes, :declared_relationships, :schema

      def pick(fields) = fields.select { names.include?(it.name) }

      def all_fields = declared_attributes + declared_relationships

      def declared_names = all_fields.map(&:name)

      def verify_field_names
        refuse_reserved_names
        refuse_repeated_names
      end

      def refuse_reserved_names
        reserved_names = declared_names & RESERVED
        return if reserved_names.empty?
        raise Collision, "#{reserved_names.join(", ")} says which record this is, not what it holds"
      end

      def refuse_repeated_names
        repeated_names = declared_names.tally.filter_map { |name, count| name if count > 1 }
        return if repeated_names.empty?
        raise Collision, "#{repeated_names.join(", ")} names two fields"
      end
    end
  end
end
