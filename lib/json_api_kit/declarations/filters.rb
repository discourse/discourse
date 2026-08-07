# frozen_string_literal: true

module JsonApiKit
  module Declarations
    # How a resource lets its listings be narrowed: the filters it offers a caller, and the scope
    # that is left once the ones a request names have been applied. Only a resource's declarations
    # say what may narrow a listing, so a filter nobody declared is refused rather than ignored.
    class Filters
      Unsupported = Class.new(StandardError)

      def initialize(declared)
        @filters = declared.index_by(&:name)
      end

      # The filter a caller names, or nothing this resource offers by that name — a request error
      # rather than a bug.
      def fetch(name)
        filters[name.to_s] or raise Unsupported, "no filter named #{name}"
      end

      # The scope narrowed by the filtering asked for — the filters to narrow by, each with its
      # value. They compose, so a listing keeps only the rows every one of them allows.
      def apply(scope, filtering = {})
        return scope if filtering.blank?
        filtering.reduce(scope) { |narrowed, (name, value)| fetch(name).apply(narrowed, value) }
      end

      private

      attr_reader :filters
    end
  end
end
