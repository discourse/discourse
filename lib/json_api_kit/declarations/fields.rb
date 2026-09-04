# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Fields
      Collision = Class.new(StandardError)

      RESERVED = %w[type id].freeze

      class << self
        def for(names, **declarations)
          return All.new(**declarations) unless names
          new(names, **declarations)
        end
      end

      def initialize(names, guardian:, attributes:, relationships:, schema:)
        @names = names
        @guardian = guardian
        @declared_attributes = attributes
        @declared_relationships = relationships
        @schema = schema
        verify_field_names
      end

      def attributes = @attributes ||= Attributes.new(pick(declared_attributes), guardian:, schema:)

      def relationships = Relationships.new(pick(declared_relationships))

      def columns = attributes.columns

      private

      attr_reader :names, :guardian, :declared_attributes, :declared_relationships, :schema

      def pick(fields) = readable(fields).select { names.include?(it.name) }

      def readable(fields) = fields.select { it.readable_by?(guardian) }

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
