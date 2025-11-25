# frozen_string_literal: true

class Service::ContractBase
  include ActiveModel::API
  include ActiveModel::Attributes
  include ActiveModel::AttributeMethods
  include ActiveModel::Validations::Callbacks

  delegate :slice, :merge, to: :to_hash

  def initialize(*args, options: nil, **kwargs)
    @__options__ = options
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

  # Override ActiveModel::Attributes.attribute to support nested contracts via block syntax
  def self.attribute(name, cast_type = nil, **options, &block)
    if block_given?
      # When a block is provided, create a nested contract class
      nested_contract_class = Class.new(Service::ContractBase)

      # Assign a constant name to the nested class so ActiveModel can generate error messages
      # This is important because ActiveModel::Errors needs model_name to work properly
      const_name = "#{name.to_s.camelize}Contract"
      const_set(const_name, nested_contract_class) unless const_defined?(const_name)

      nested_contract_class.class_eval(&block)

      # Store the nested contract class for introspection
      @nested_contract_classes ||= {}
      @nested_contract_classes[name.to_sym] = nested_contract_class

      # Register the attribute with our custom nested type
      super(name, Service::NestedContractType.new(contract_class: nested_contract_class), **options)
    else
      super(name, cast_type, **options)
    end
  end

  def self.nested_contract_classes
    @nested_contract_classes ||= {}
  end

  # Override valid? to validate nested contracts
  def valid?(context = nil)
    super && nested_attributes_valid?
  end

  private

  def nested_attributes_valid?
    self.class.nested_contract_classes.all? do |attr_name, _contract_class|
      nested_value = public_send(attr_name)
      next true if nested_value.nil?

      if nested_value.respond_to?(:valid?)
        is_valid = nested_value.valid?
        unless is_valid
          # Add a base error indicating the nested attribute is invalid
          # We avoid copying individual error messages to prevent issues with anonymous classes
          errors.add(attr_name, :invalid)
        end
        is_valid
      else
        true
      end
    end
  end
end
