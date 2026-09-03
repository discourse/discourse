# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declarations
      DERIVED_FROM_AN_ATTRIBUTE = %i[field sort anchor].freeze

      def initialize(type)
        @type = type.to_s
        @transformations = []
      end

      def renamed_attribute(from:, to:)
        DERIVED_FROM_AN_ATTRIBUTE.each do
          transformations << Rename.new(kind: it, type:, from: from.to_s, to: to.to_s)
        end
      end

      def to_a = transformations

      private

      attr_reader :type, :transformations
    end
  end
end
