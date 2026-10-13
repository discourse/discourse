# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class RemovedSort
      attr_reader :type, :name

      delegate :key, to: :sort

      def initialize(type, name, **options)
        @type = type.to_s
        @name = "__removed_sort_#{object_id}"
        @sort = JsonApiKit::Declarations::Sort.for(name, **options)
      end

      def transformations
        Declaration::RenamedName.new(type, [Name::Sort], from: sort.name, to: name).transformations
      end

      private

      attr_reader :sort
    end
  end
end
