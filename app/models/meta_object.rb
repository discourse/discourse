class MetaObject < ActiveRecord::Base
  belongs_to :meta_schema

  has_many :meta_fields, dependent: :destroy
  has_many :string_meta_fields, through: :meta_fields
  has_many :enum_meta_fields, through: :meta_fields
  has_many :integer_meta_fields, through: :meta_fields

  accepts_nested_attributes_for :string_meta_fields, :enum_meta_fields, :integer_meta_fields
end
