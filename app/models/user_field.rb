class UserField < ActiveRecord::Base
  validates_presence_of :name, :description, :field_type
end
