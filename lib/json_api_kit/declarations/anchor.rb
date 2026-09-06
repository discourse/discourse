# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Anchor
      class NoRow < BadRequest
        def initialize(name, value)
          @name = name
          super("No record has #{name} #{value.inspect}.")
        end

        def title = "No row for the anchor"

        def source = { parameter: "page[anchor][#{name}]" }

        private

        attr_reader :name
      end

      IDENTITY = "id"

      attr_reader :name

      def initialize(name, &condition)
        @name = name.to_s
        @condition = condition
      end

      def locatable_in?(order) = computed? || order.leading.named?(name) || identity?

      def locate(scope, value:, order:, guardian:)
        kind_for(order.leading, value, guardian).locate(scope, order:)
      end

      private

      attr_reader :condition

      def kind_for(key, value, guardian)
        return Computed.new(condition, guardian) if computed?
        return Value.new(key, value) if key.named?(name)
        return Identity.new(name, value) if identity?
        raise ArgumentError, "The anchor is #{name}, but this request sorts by #{key}."
      end

      def computed? = condition.present?

      def identity? = name == IDENTITY
    end
  end
end
