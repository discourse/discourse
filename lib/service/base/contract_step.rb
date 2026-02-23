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
          class_name.new(**default_values.merge(context[:params]), options: context[:options])
        context[contract_name] = contract
        if contract.invalid?
          context[result_key].fail(errors: contract.errors, parameters: contract.raw_attributes)
          context.fail!
        end
        contract.freeze
      end

      private

      def contract_name
        return :params if default?
        :"#{name}_contract"
      end

      def default?
        name.to_sym == :default
      end

      def default_values
        return {} unless default_values_from
        model = context[default_values_from]
        model.try(:attributes).try(:with_indifferent_access) || model
      end
    end
  end
end
