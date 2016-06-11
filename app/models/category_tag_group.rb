class CategoryTagGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :tag_group
end
