class PostSearchData < ActiveRecord::Base
  belongs_to :post

  validates_presence_of :search_data
end
