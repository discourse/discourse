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

  def [](key)
    public_send(key)
  end

  def to_hash
    attributes.symbolize_keys
  end

  def raw_attributes
    @attributes.values_before_type_cast
  end
end
