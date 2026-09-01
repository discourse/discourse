# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Readable
      ALWAYS = ->(_guardian) { true }

      class << self
        def for(rule) = (rule.arity == 2 ? PerRecord : PerUser).new(rule)
      end

      def initialize(rule)
        @rule = rule
      end

      private

      attr_reader :rule
    end
  end
end
