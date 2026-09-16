# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declarations
      def initialize(type)
        @type = type
        @transformations = []
        @default_sorts = []
      end

      attr_reader :transformations, :default_sorts

      def changed_default_sort(from:) = default_sorts << DefaultSort.new(type, from)

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

      def declare(declaration) = transformations.concat(declaration.transformations)
    end
  end
end
