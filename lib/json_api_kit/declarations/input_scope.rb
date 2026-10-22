# frozen_string_literal: true

module JsonApiKit
  module Declarations
    # A block that narrows the visible rows by request inputs on every request. It receives the
    # rows, the guardian, and one keyword per filter it reads; a required keyword names a filter
    # with a default, so it always gets a value.
    class InputScope
      INPUT_KINDS = %i[keyreq key].freeze

      def initialize(block)
        @block = block
      end

      def verify!(resource, names:, defaults:)
        block.parameters.each do |kind, name|
          if kind == :keyrest
            raise ArgumentError,
                  "#{resource}: the input scope takes **#{name}, so a misspelled input would " \
                    "go unnoticed; name each input as a keyword"
          end
          next if INPUT_KINDS.exclude?(kind)
          if names.exclude?(name.to_s)
            raise ArgumentError,
                  "#{resource}: the input scope reads #{name}, which no filter declares"
          end
          if kind == :keyreq && defaults.exclude?(name.to_s)
            raise ArgumentError,
                  "#{resource}: the input scope requires #{name}, but its filter has no default"
          end
        end
      end

      # Combined with `and`, not `merge`: `merge` replaces a condition on a column the block also
      # constrains, which could drop part of what the scope keeps visible.
      def apply(rows, guardian:, values:)
        inputs = keywords.select { values.key?(it) }.to_h { [it.to_sym, values[it]] }
        rows.and(block.call(rows, guardian, **inputs))
      end

      private

      attr_reader :block

      def keywords = block.parameters.filter_map { |kind, name| name.to_s if kind.in?(INPUT_KINDS) }
    end
  end
end
