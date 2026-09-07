# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Filter
      attr_reader :name

      def initialize(name, &condition)
        @name = name.to_s
        @condition = condition || Equality.new(@name)
      end

      def apply(scope, value) = condition.call(scope, value)

      private

      attr_reader :condition
    end
  end
end
