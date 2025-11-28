# frozen_string_literal: true

class Service::ContractBase
  include ActiveModel::API
  include ActiveModel::Attributes
  include ActiveModel::AttributeMethods
  include ActiveModel::Validations::Callbacks

  delegate :slice, :merge, to: :to_hash

  class << self
    def attribute(name, cast_type = nil, **options, &block)
      return super(name, cast_type, **options) unless block_given?

      nested_contract_class = Class.new(Service::ContractBase)

      # Assign a constant name to the nested class so ActiveModel can generate error messages
      # This is important because ActiveModel::Errors needs model_name to work properly
      const_name = "#{name.to_s.camelize}Contract"
      const_set(const_name, nested_contract_class)

      nested_contract_class.class_eval(&block)

      super(name, Service::NestedContractType.new(contract_class: nested_contract_class), **options)
    end
  end

  def initialize(*args, options: nil, **kwargs)
    @__options__ = options
    kwargs.slice!(*self.class.attribute_names.map(&:to_sym))
    super(*args, **kwargs)
  end

  def options
    @__options__
  end

  def to_hash
    attributes.symbolize_keys.transform_values do |v|
      v.is_a?(Service::ContractBase) ? v.to_hash : v
    end
  end

  def raw_attributes
    @attributes.values_before_type_cast
  end

  def valid?(context = nil)
    super && nested_attributes_valid?
  end

  private

  def nested_attributes_valid?
    @attributes
      .each_value
      .select { _1.type.is_a?(Service::NestedContractType) }
      .all? do |contract|
        errors.add(contract.name, :invalid) if contract.value.invalid?
        contract.value.valid?
      end
  end
end
