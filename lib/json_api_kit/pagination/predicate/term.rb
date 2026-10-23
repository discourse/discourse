# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Predicate
      class Term
        delegate :identifier, :operator, to: :key
        delegate :name, :nulls_trailing?, :nulls_read_first?, to: :key, private: true

        def self.for(key, value) = value.nil? ? Null.new(key) : new(key, value)

        def initialize(key, value)
          @key = key
          @value = value
        end

        def comparable? = !nulls_trailing?

        def placeholder = ":#{name}"

        def matches = "#{identifier} = #{placeholder}"

        def disjuncts(matched) = ["(#{(matched.map(&:matches) << sorts_after).join(" AND ")})"]

        def bound_on(comparison) = "#{at_or_after_value} AND (#{comparison})"

        def bindings = { name => key.cast(value) }

        private

        attr_reader :key, :value

        def sorts_after
          return after_value unless nulls_trailing?
          "(#{after_value} OR #{identifier} IS NULL)"
        end

        def after_value = "#{identifier} #{operator} #{placeholder}"

        def at_or_after_value = "#{identifier} #{operator}= #{placeholder}"
      end
    end
  end
end
