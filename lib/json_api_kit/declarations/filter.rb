# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Filter
      # What a condition declared with a third parameter receives besides the scope and the value.
      Context = Data.define(:guardian, :edition, :filtering)

      NO_DEFAULT = Object.new.freeze
      private_constant :NO_DEFAULT

      attr_reader :name

      def initialize(name, default: NO_DEFAULT, &condition)
        @name = name.to_s
        @condition = condition || Equality.new(@name)
        # Deep-frozen, so one request can never change the default the next one reads.
        @default = default.equal?(NO_DEFAULT) ? default : Ractor.make_shareable(default.deep_dup)
      end

      # Whether the filter applies a value of its own when a request leaves it out.
      def default? = !@default.equal?(NO_DEFAULT)

      def default = default? ? @default : nil

      def apply(scope, value, context = nil)
        contextual? ? condition.call(scope, value, context) : condition.call(scope, value)
      end

      private

      attr_reader :condition

      # Arity selects the signature, like Readable.for, so two-parameter conditions keep working.
      def contextual? = condition.respond_to?(:arity) && condition.arity.abs >= 3
    end
  end
end
