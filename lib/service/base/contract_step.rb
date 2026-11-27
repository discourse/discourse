# frozen_string_literal: true

module Service
  module Base
    # @!visibility private
    class ContractStep < Step
      attr_reader :default_values_from

      def initialize(name, method_name = name, class_name: nil, default_values_from: nil)
        super(name, method_name, class_name:)
        @default_values_from = default_values_from
      end

      def run_step
        contract =
          class_name.new(
            params.to_hash,
            options: context[:options],
            model: (context[default_values_from] if default_values_from),
          )
        context[contract_name] = contract
        if contract.invalid?
          context[result_key].fail(errors: contract.errors, parameters: contract.raw_attributes)
          context.fail!
        end
        contract.freeze
      end

      private

      def params = context[:params]

      def contract_name
        return :params if default?
        :"#{name}_contract"
      end

      def default?
        name.to_sym == :default
      end
    end
  end
end
