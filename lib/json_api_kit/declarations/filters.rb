# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Filters
      delegate :fetch, to: :filters

      def initialize(declarations)
        @declarations = declarations
      end

      def names = filters.keys

      def with(additional_filters) = self.class.new(declarations.chain(additional_filters))

      def apply(scope, filtering = {})
        return scope if filtering.blank?
        filtering.reduce(scope) { |narrowed, (name, value)| fetch(name).apply(narrowed, value) }
      end

      private

      attr_reader :declarations

      def filters = @filters ||= declarations.index_by(&:name)
    end
  end
end
