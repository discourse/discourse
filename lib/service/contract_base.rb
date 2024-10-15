# frozen_string_literal: true

class Service::ContractBase
  include ActiveModel::API
  include ActiveModel::Attributes
  include ActiveModel::AttributeMethods
  include ActiveModel::Validations::Callbacks

  def raw_attributes
    @attributes.values_before_type_cast
  end
end
