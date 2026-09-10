# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declarations
      DERIVED_FROM_AN_ATTRIBUTE = [Name::Field, Name::Sort, Name::Anchor].freeze
      NO_CONVERSION = ->(value) { value }

      def initialize(type)
        @type = type.to_s
        @transformations = []
      end

      def renamed_attribute(from:, to:, up: NO_CONVERSION, down: NO_CONVERSION)
        if [up, down].count(NO_CONVERSION) == 1
          raise ArgumentError, "Declare both up: and down: to rename #{from} to #{to}."
        end
        unless [up, down].all? { it.respond_to?(:call) }
          raise ArgumentError, "up: and down: must respond to call, to rename #{from} to #{to}."
        end
        DERIVED_FROM_AN_ATTRIBUTE.each do |kind|
          transformations << Rename.new(
            from: kind.new(value: from.to_s, type:),
            to: kind.new(value: to.to_s, type:),
            up:,
            down:,
          )
        end
      end

      def to_a = transformations

      private

      attr_reader :type, :transformations
    end
  end
end
