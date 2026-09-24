# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declarations
      def initialize(type)
        @type = type
        @transformations = []
        @default_sorts = []
        @removed_filters = []
      end

      attr_reader :default_sorts, :removed_filters

      def transformations = @transformations + removed_filters.flat_map(&:transformations)

      def changed_default_sort(from:) = default_sorts << DefaultSort.new(type, from)

      def removed_filter(name, &condition)
        removed_filters << RemovedFilter.new(type, name, &condition)
      end

      def renamed_attribute(**) = declare(Declaration::RenamedAttribute.new(type, **))

      def merged_attributes(**) = declare(Declaration::MergedAttributes.new(type, **))

      def split_attribute(**) = declare(Declaration::SplitAttribute.new(type, **))

      def renamed_sort(from:, to:)
        declare(Declaration::RenamedName.new(type, [Name::Sort], from:, to:))
      end

      def renamed_filter(from:, to:)
        declare(Declaration::RenamedName.new(type, [Name::Filter], from:, to:))
      end

      def renamed_relationship(from:, to:)
        declare(Declaration::RenamedName.new(type, [Name::Relationship, Name::Field], from:, to:))
      end

      private

      attr_reader :type

      def declare(declaration) = @transformations.concat(declaration.transformations)
    end
  end
end
