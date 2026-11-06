# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      module Declarations
        class Sorts
          delegate :fetch, to: :declarations
          delegate :schema, :sort_key, to: :builder, private: true

          def initialize(declarations, builder:, unique_by: nil)
            @declarations = declarations
            @builder = builder
            @unique_by = Array(unique_by.presence || schema.primary_key)
          end

          def keyset(ordering) = Pagination::Keyset.new(keys(ordering))

          private

          attr_reader :declarations, :unique_by, :builder

          def keys(ordering)
            [
              *ordering.map { |name, direction| fetch(name).key(builder:, direction:) },
              *unique_keys(leading_direction(ordering)),
            ]
          end

          def unique_keys(direction) = unique_by.map { sort_key(it, direction:) }

          def leading_direction(ordering) = ordering.values.first || :asc
        end
      end
    end
  end
end
