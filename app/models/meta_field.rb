class MetaField < ActiveRecord::Base
  belongs_to :meta_object
  belongs_to :meta_field_type

  has_one :string_meta_field, dependent: :destroy
  has_one :enum_meta_field, dependent: :destroy
  has_one :integer_meta_field, dependent: :destroy

  acccepts_nested_attributes_for :meta_field_values
end
