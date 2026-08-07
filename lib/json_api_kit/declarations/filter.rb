# frozen_string_literal: true

module JsonApiKit
  module Declarations
    # One way a resource lets its listings be narrowed: the name a caller filters by, and the
    # condition its value puts on a scope.
    #
    # A filter over a column of the model need say nothing else — the condition is equality (see
    # Equality), and the value is read as that column's type by the query itself. A block is a
    # condition like any other, and takes the place of that one.
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
