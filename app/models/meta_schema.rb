class MetaSchema < ActiveRecord::Base
  has_many :meta_field_types, dependent: :destroy
  has_many :meta_objects, dependent: :destroy
end
