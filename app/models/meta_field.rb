class MetaField < ActiveRecord::Base
  belongs_to :meta_object
  belongs_to :meta_column

  has_one :string_meta_field, dependent: :destroy
  has_one :enum_meta_field, dependent: :destroy
  has_one :integer_meta_field, dependent: :destroy

  acccepts_nested_attributes_for :string_meta_field, :enum_meta_field, :integer_meta_field

  validates :meta_object_id, presence: true
  validates :meta_column_id, presence: true
end
