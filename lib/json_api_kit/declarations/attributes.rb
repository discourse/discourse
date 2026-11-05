# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Attributes
      include Enumerable

      delegate :each, to: :attributes

      def initialize(attributes, guardian:, type:)
        @attributes = attributes
        @guardian = guardian
        @type = type
        @field_names = {}
      end

      def names = attributes.map(&:name)

      def values_for(record) = readable(record).to_h { [field_name(it), it.value_for(record)] }

      private

      attr_reader :attributes, :guardian, :type, :field_names

      def readable(record) = attributes.select { it.readable_for?(guardian, record) }

      def field_name(attribute)
        field_names[attribute] ||= Name::Field.new(value: attribute.name, type:)
      end
    end
  end
end
