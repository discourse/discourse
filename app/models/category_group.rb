class CategoryGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :group
end
