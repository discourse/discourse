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

      def to_a = transformations

      private

      attr_reader :type, :transformations

      def declare(declaration) = transformations.concat(declaration.transformations)
    end
  end
end
