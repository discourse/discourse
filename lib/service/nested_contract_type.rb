# frozen_string_literal: true

module Service
  class NestedContractType < ActiveModel::Type::Value
    attr_reader :contract_class, :nested_type

    def initialize(contract_class:, nested_type: :hash)
      super()
      @contract_class = contract_class
      @nested_type = nested_type.to_s.inquiry
    end

    def cast_value(value)
      case value
      when ->(*) { nested_type.hash? }
        cast_hash(value)
      when ->(*) { nested_type.array? && value.is_a?(Array) }
        value.filter_map(&method(:cast_hash))
      else
        nil
      end
    end

    private

    def cast_hash(value)
      return unless value.is_a?(Hash)
      contract_class.new(**value)
    end
  end
end
