# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class RemovedFilter
      attr_reader :type, :name

      delegate :apply, to: :filter

      def initialize(type, name, &condition)
        @type = type.to_s
        @name = "__removed_filter_#{object_id}"
        @filter = JsonApiKit::Declarations::Filter.new(name, &condition)
      end

      def transformations
        Declaration::RenamedName.new(
          type,
          [Name::Filter],
          from: filter.name,
          to: name,
        ).transformations
      end

      private

      attr_reader :filter
    end
  end
end
