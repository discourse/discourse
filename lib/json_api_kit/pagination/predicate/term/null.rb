# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Predicate
      class Term
        # A term whose cursor value is null. Every comparison against NULL is NULL, so this
        # one matches by testing for null instead, and contributes nothing else to the
        # predicate.
        class Null < Term
          def initialize(key) = super(key, nil)

          def comparable? = false

          def matches = "#{identifier} IS NULL"

          # Where nulls sort last nothing follows one, so there is no disjunct to contribute;
          # where they sort first, every row that has a value does.
          def disjuncts(matched)
            return super if nulls_read_first?
            []
          end

          # A bound against NULL is NULL, and would leave the whole comparison matching
          # nothing at all.
          def bound_on(comparison) = comparison

          def bindings = {}

          private

          # Where nulls sort first, the rows following a null are the rows that have a value.
          def after = "#{identifier} IS NOT NULL"
        end
      end
    end
  end
end
