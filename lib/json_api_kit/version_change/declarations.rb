# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declarations
      def initialize(type)
        @type = type
        @transformations = []
      end

      def renamed_attribute(**) = declare(Declaration::RenamedAttribute.new(type, **))

      def merged_attributes(**) = declare(Declaration::MergedAttributes.new(type, **))

      def renamed_sort(from:, to:)
        declare(Declaration::RenamedName.new(type, [Name::Sort], from:, to:))
      end

      def renamed_filter(from:, to:)
        declare(Declaration::RenamedName.new(type, [Name::Filter], from:, to:))
      end

      def renamed_relationship(from:, to:)
        declare(Declaration::RenamedName.new(type, [Name::Relationship, Name::Field], from:, to:))
      end

      def to_a = transformations

      private

      attr_reader :type, :transformations

      def declare(declaration) = transformations.concat(declaration.transformations)
    end
  end
end
