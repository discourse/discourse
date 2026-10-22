# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class RemovedFilter
      attr_reader :type, :name, :collection

      delegate :apply, :default?, :default, to: :filter

      def initialize(type, name, collection: nil, &condition)
        @type = type.to_s
        @collection = collection&.to_s
        @name = "__removed_filter_#{object_id}"
        @filter = JsonApiKit::Declarations::Filter.new(name, &condition)
      end

      def transformations
        Declaration::RenamedName.new(
          type,
          [Name::Filter],
          from: filter.name,
          to: name,
          collection:,
        ).transformations
      end

      private

      attr_reader :filter
    end
  end
end
