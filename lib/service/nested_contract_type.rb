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

    def cast_value(value)
      case value
      when Hash
        contract_class.new(**value.symbolize_keys)
      else
        value
      end
    end
  end
end
