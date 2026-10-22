# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class RemovedFilters
      def initialize(filters)
        @filters = filters.group_by { [it.type, it.collection] }
        @filters.default = [].freeze
      end

      def each_for(type, collection = nil, &) = filters[[type, collection]].each(&)

      private

      attr_reader :filters
    end
  end
end
