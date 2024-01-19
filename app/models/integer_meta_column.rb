class IntegerMetaColumn < ActiveRecord::Base
  has_one :meta_column, as: :detailable, touch: true
end
