# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class RemovedSorts
      def initialize(sorts)
        @sorts = sorts.group_by(&:type)
        @sorts.default = [].freeze
      end

      def each_for(type, &) = sorts[type].each(&)

      private

      attr_reader :sorts
    end
  end
end
