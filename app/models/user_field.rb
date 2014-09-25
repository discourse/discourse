class UserField < ActiveRecord::Base
  validates_presence_of :name, :field_type
end

