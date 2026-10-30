# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Sorts
      delegate :fetch, to: :sorts

      def initialize(declarations)
        @declarations = declarations
      end

      def names = sorts.keys

      def with(additional_sorts)
        self.class.new(declarations.chain(additional_sorts))
      end

      private

      attr_reader :declarations

      def sorts = @sorts ||= declarations.index_by(&:name)
    end
  end
end
