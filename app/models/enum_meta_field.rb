class EnumMetaField < ActiveRecord::Base
  has_one :meta_field, as: :fieldable, touch: true
end
