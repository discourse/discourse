# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Predicate
      class Term
        class Null < Term
          def initialize(key) = super(key, nil)

          def comparable? = false

          def matches = "#{identifier} IS NULL"

          def disjuncts(matched)
            return super if nulls_read_first?
            []
          end

          def bound_on(comparison) = comparison

          def bindings = {}

          private

          def sorts_after = "#{identifier} IS NOT NULL"
        end
      end
    end
  end
end
