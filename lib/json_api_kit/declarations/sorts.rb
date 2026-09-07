# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Sorts
      delegate :fetch, to: :sorts

      def initialize(sorts, schema:, default: {}, unique_by: nil)
        @sorts = sorts.index_by(&:name)
        @schema = schema
        @default = default.to_h.transform_keys(&:to_s)
        @unique_by = Array(unique_by.presence || schema.primary_key)
      end

      def keyset(ordering = {}) = Pagination::Keyset.new(keys(ordering.presence || default))

      private

      attr_reader :sorts, :schema, :default, :unique_by

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
