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

      nested_contract_class =
        Class.new(Service::ContractBase) do
          define_singleton_method(:name) { "#{name}_contract".classify }
          class_eval(&block)
        end
      super(name, Service::NestedContractType.new(contract_class: nested_contract_class), **options)
    end
  end

  def initialize(*args, options: nil, **kwargs)
    @__options__ = options
    kwargs.deep_symbolize_keys!.slice!(*self.class.attribute_names.map(&:to_sym))
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
      .select { _1.type.is_a?(Service::NestedContractType) && _1.value }
      .all? do |attribute|
        errors.add(attribute.name, :invalid) if attribute.value.invalid?
        attribute.value.valid?
      end
  end
end
