# frozen_string_literal: true

module Service
  # Custom ActiveModel::Type for handling nested contract attributes
  # This allows contracts to define nested structures like:
  #
  #   attribute :user do
  #     attribute :username, :string
  #     attribute :age, :integer
  #   end
  #
  # Which can then accept data like: {user: {username: "alice", age: 30}}
  class NestedContractType < ActiveModel::Type::Value
    attr_reader :contract_class

    def initialize(contract_class:)
      super()
      @contract_class = contract_class
    end

    def serializable?(_)
      false
    end

    def cast_value(value)
      return nil if value.nil?
      return value if value.is_a?(contract_class)

      # Convert hash-like values to contract instances
      case value
      when Hash
        contract_class.new(**value.symbolize_keys)
      when ActionController::Parameters
        contract_class.new(**value.to_unsafe_h.symbolize_keys)
      else
        value
      end
    end
  end
end
