# frozen_string_literal: true

module Service
  class ResourceImport
    class Field
      delegate :name, :type, to: :declaration

      def initialize(declaration)
        @declaration = declaration
      end

      def parameter_name = name

      def apply_to(contract) = contract.attribute(parameter_name, type)

      private

      attr_reader :declaration
    end
  end
end
