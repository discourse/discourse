# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      class Definition < Adapter::Definition
        class << self
          def anchor(...) = Declarations::Anchor.for(...)

          def required_owner_fields(name, owner_resource:)
            [owner_resource.schema.owner_key(name.to_sym)]
          end
        end

        def schema = @schema ||= Schema.new(model)

        def order(ordering) = Pagination::Order.new(sorts.keyset(ordering), type:)

        def sort_key(name, direction:, **options)
          Declarations::Sort.for(name, **options).key(schema:, direction:)
        end

        def parse_cursor(raw) = Pagination::Cursor.parse(raw)

        def valid_cursor?(raw) = Pagination::Cursor.valid?(raw)

        def paged_from?(cursor, ordering:) = order(ordering).compatible_with?(cursor:)

        def anchored_by?(anchor_name:, ordering:)
          anchor_declarations
            .detect { it.name == anchor_name.to_s }
            .then { |anchor| anchor.nil? || anchor.locatable_in?(order(ordering)) }
        end

        def leading_sort_name(ordering) = order(ordering).leading.name.to_s

        private

        delegate :model, :type, :unique_key, :anchor_declarations, to: :declarations, private: true

        def sorts
          @sorts ||=
            Declarations::Sorts.new(declarations.sorts, unique_by: unique_key, builder: self)
        end
      end
    end
  end
end
