# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Predicate
      # One key of the order bound to the cursor's value for that key, and the comparisons
      # a row has to satisfy against it.
      #
      # A term composes its own contribution to the predicate rather than answering
      # questions about itself, so a cursor value that is null contributes differently
      # instead of being asked about everywhere (see Term::Null). The nil is read once, on
      # the way in.
      class Term
        OPERATORS = { asc: ">", desc: "<" }.freeze

        delegate :identifier, to: :key
        delegate :direction, :name, :nulls_trailing?, :nulls_read_first?, to: :key, private: true

        def self.for(key, value) = value.nil? ? Null.new(key) : new(key, value)

        def initialize(key, value)
          @key = key
          @value = value
        end

        # Whether the term can take part in a row-wise comparison, which drops every row holding
        # a NULL: a null value cannot (see Null), and neither can a key whose nulls follow its
        # values, those rows belonging in the comparison rather than out of it.
        def comparable? = !nulls_trailing?

        def operator = OPERATORS[direction]

        def placeholder = ":#{name}"

        # A row sitting at the cursor's value for this key.
        def matches = "#{identifier} = #{placeholder}"

        # The disjunct where every key before this one matched the cursor exactly and this
        # one moved past it. A list, because a term may have none to contribute.
        def disjuncts(matched) = ["(#{(matched.map(&:matches) << after).join(" AND ")})"]

        # Bounds the whole comparison by this term, for planners that give up on a chain of
        # ORs.
        def bound_on(comparison) = "#{at_or_after} AND (#{comparison})"

        def bindings = { name => key.cast(value) }

        private

        attr_reader :key, :value

        # The rows following the cursor's value at this key. Where the key's nulls follow its
        # values, the rows it is null in follow this one too, and no comparison reaches them.
        def after
          return moved_past unless nulls_trailing?
          "(#{moved_past} OR #{identifier} IS NULL)"
        end

        def moved_past = "#{identifier} #{operator} #{placeholder}"

        def at_or_after = "#{identifier} #{operator}= #{placeholder}"
      end
    end
  end
end
