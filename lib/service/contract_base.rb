# frozen_string_literal: true

class Service::ContractBase
  include ActiveModel::API
  include ActiveModel::Attributes
  include ActiveModel::AttributeMethods
  include ActiveModel::Validations::Callbacks

  delegate :slice, :merge, :except, to: :to_hash

  class << self
    def attribute(name, cast_type = nil, **options, &block)
      return super(name, cast_type, **options) unless block_given?

      nested_contract_class =
        Class.new(Service::ContractBase) do
          define_singleton_method(:name) { "#{name}_contract".classify }
          class_eval(&block)
        end
      super(
        name,
        Service::NestedContractType.new(
          contract_class: nested_contract_class,
          nested_type: cast_type || :hash,
        ),
        **options,
      )
    end
  end

  def initialize(attributes = nil, options: nil, model: nil, **kwargs)
    @__options__ = options
    @__model__ = model
    input = (attributes&.to_hash || {}).merge(kwargs)
    @__provided_attributes__ = (input.keys.map(&:to_s) & self.class.attribute_names).freeze
    values = model ? default_values.deep_merge(input) : input
    super(values.deep_symbolize_keys.slice(*self.class.attribute_names.map(&:to_sym)))
  end

  def provided?(name) = @__provided_attributes__.include?(name.to_s)

  def options
    @__options__
  end

  def model
    @__model__
  end

  def to_hash
    attributes.symbolize_keys.deep_transform_values do
      it.is_a?(Service::ContractBase) ? it.to_hash : it
    end
  end

  def raw_attributes
    @attributes.values_before_type_cast
  end

  def valid?(context = nil)
    [super, nested_attributes_valid?].all?
  end

  protected

  def options=(options)
    @__options__ = options
  end

  private

  def default_values
    (@__model__.try(:attributes) || @__model__).with_indifferent_access
  end

  def nested_attributes_valid?
    nested_attributes.map(&method(:validate_nested)).all?
  end

  def nested_attributes
    @attributes.each_value.select { it.type.is_a?(Service::NestedContractType) && it.value }
  end

  def validate_nested(attribute)
    Array
      .wrap(attribute.value)
      .map
      .with_index do |contract, index|
        contract.options = options
        next true if contract.valid?
        import_nested_errors(contract, attribute, index)
        false
      end
      .all?
  end

  def import_nested_errors(contract, attribute, index)
    array_index = "[#{index}]" if attribute.value.is_a?(Array)
    contract.errors.each do |error|
      errors.import(error, attribute: :"#{attribute.name}#{array_index}.#{error.attribute}")
    end
  end
end
