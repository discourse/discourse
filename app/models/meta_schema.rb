class MetaSchema < ActiveRecord::Base
  has_many :meta_columns, dependent: :destroy
  has_many :meta_objects, dependent: :destroy
end
