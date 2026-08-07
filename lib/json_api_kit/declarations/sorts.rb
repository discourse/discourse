# frozen_string_literal: true

module JsonApiKit
  module Declarations
    # How a resource lets its listings be ordered: the sorts it declares, the order it reads when
    # a request names none, and the key that makes any of them unique. It answers with the keyset a
    # page is read along, so nothing else has to know how a request becomes an order.
    class Sorts
      Unsupported = Class.new(StandardError)

      def initialize(declared, model:, default: {}, unique_by: nil)
        @sorts = declared.index_by(&:name)
        @model = model
        @default = default
        @unique_by = Array(unique_by.presence || model.primary_key)
      end

      # The sort a client names, or nothing this resource offers by that name — a request error
      # rather than a bug, since only a resource's declarations say what is orderable.
      def fetch(name)
        sorts[name.to_s] or raise Unsupported, "no sort named #{name}"
      end

      # The keyset a page is read along, for the ordering asked for — the sorts to read by, each
      # with its direction — or for the resource's own when nothing was asked.
      def keyset(ordering = {}) = Pagination::Keyset.new(keys(ordering.presence || default))

      private

      attr_reader :sorts, :model, :default, :unique_by

      # The keys of the order, and behind them the ones no two rows can share: a page read from an
      # order that ties is a page that repeats a row or skips one.
      def keys(ordering)
        [
          *ordering.map { |name, direction| fetch(name).key(model:, direction:) },
          *unique_keys(leading_direction(ordering)),
        ]
      end

      def unique_keys(direction) = unique_by.map { Sort.new(it).key(model:, direction:) }

      # The unique key follows the leading key's direction, since one index serves a uniform order
      # read either way where a mixed one needs an index of its own.
      def leading_direction(ordering) = ordering.values.first || :asc
    end
  end
end
