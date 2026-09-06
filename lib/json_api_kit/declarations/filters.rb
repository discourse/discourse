# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Filters
      delegate :fetch, to: :filters

      def initialize(filters)
        @filters = filters.index_by(&:name)
      end

      def apply(scope, filtering = {})
        return scope if filtering.blank?
        filtering.reduce(scope) { |narrowed, (name, value)| fetch(name).apply(narrowed, value) }
      end

      private

      attr_reader :filters
    end
  end
end
