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

          # Within a group of NULLs nothing sorts after NULL, so no row could ever satisfy
          # this disjunct.
          def disjuncts(_matched) = []

          # A bound against NULL is NULL, and would leave the whole comparison matching
          # nothing at all.
          def bound_on(comparison) = comparison

          def bindings = {}
        end
      end
    end
  end
end
