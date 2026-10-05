# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Sorts
      delegate :fetch, to: :sorts

      def initialize(declarations, schema:, unique_by: nil)
        @declarations = declarations
        @schema = schema
        @unique_by = Array(unique_by.presence || schema.primary_key)
      end

      def names = sorts.keys

      def with(additional_sorts)
        self.class.new(declarations.chain(additional_sorts), schema:, unique_by:)
      end

      def keyset(ordering) = Pagination::Keyset.new(keys(ordering))

      private

      attr_reader :declarations, :schema, :unique_by

      def sorts = @sorts ||= declarations.index_by(&:name)

      def keys(ordering)
        [
          *ordering.map { |name, direction| fetch(name).key(schema:, direction:) },
          *unique_keys(leading_direction(ordering)),
        ]
      end

      def unique_keys(direction) = unique_by.map { Sort.for(it).key(schema:, direction:) }

      def leading_direction(ordering) = ordering.values.first || :asc
    end
  end
end
