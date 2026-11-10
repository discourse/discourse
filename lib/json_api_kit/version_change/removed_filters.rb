# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class RemovedFilters
      def initialize(filters)
        @filters = filters.group_by(&:type)
        @filters.default = [].freeze
      end

      def each_for(type, &) = filters[type].each(&)

      private

      attr_reader :filters
    end
  end
end
