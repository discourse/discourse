# frozen_string_literal: true

module Service
  class ResourceImport
    class IdentifierValidator < ActiveModel::EachValidator
      def validate_each(contract, attribute, value)
        return unless contract.provided?(attribute)

        contract.errors.add(attribute, :invalid) if failed_cast?(contract, attribute, value)

        Array
          .wrap(value)
          .each_with_index do |identifier, index|
            next unless identifier.nil?
            contract.errors.import(
              ActiveModel::Error.new(contract, attribute, :invalid, value: identifier),
              attribute: :"#{attribute}[#{index}]",
            )
          end
      end

      private

      def failed_cast?(contract, attribute, value)
        value.nil? && !contract.raw_attributes[attribute.to_s].nil?
      end
    end
  end
end
