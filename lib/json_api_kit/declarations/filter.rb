# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Filter
      attr_reader :name

      def initialize(name, &condition)
        @name = name.to_s
        @condition = condition
      end

      def apply(scope, value, adapter:)
        return condition.call(scope, value) if condition
        adapter.filter(scope, name, value)
      end

      private

      attr_reader :condition
    end
  end
end
