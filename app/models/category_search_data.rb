class CategorySearchData < ActiveRecord::Base
  belongs_to :category

  validates_presence_of :search_data
end
