# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract < Service::ContractBase
      module RawAttributes
        extend ActiveSupport::Concern

        included { attribute_method_suffix "_before_type_cast", parameters: false }

        def attribute_before_type_cast(name) = raw_attributes[name]
      end

      class IndifferentHashType < ActiveModel::Type::Value
        def cast_value(value)
          value.with_indifferent_access if value.is_a?(Hash)
        end
      end

      include RawAttributes
      INDIFFERENT_HASH = IndifferentHashType.new

      validate :check_shapes
      validate :check_unknown_parameters

      def read_attribute_for_validation(name)
        return unless respond_to?(name)
        super
      end

      private

      def resource = options[:resource]

      def raw_parameters = options[:raw_parameters]

      def comparable?(value) = !value.is_a?(Enumerable)

      def refuse_unknown(attribute, names)
        names.each { errors.add(attribute, :no_such_name, name: it, message: "no such name") }
      end

      def check_shapes
        self.class.attribute_types.each do |name, type|
          next unless type.is_a?(IndifferentHashType) || type.is_a?(Service::NestedContractType)
          next if attribute_before_type_cast(name).nil? || !public_send(name).nil?
          errors.add(name, :bad_shape, message: "bad shape")
        end
      end

      def check_unknown_parameters = check_parameters(raw_parameters, self.class)

      def check_parameters(parameters, contract, prefix = nil)
        (parameters.keys - contract.attribute_names).each do |name|
          errors.add(
            [prefix, name].compact.join(".").to_sym,
            :unknown_parameter,
            message: "unknown parameter",
          )
        end
        contract.attribute_types.each do |name, type|
          next unless type.is_a?(Service::NestedContractType) && attributes[name]
          check_parameters(parameters[name], type.contract_class, name)
        end
      end
    end
  end
end
