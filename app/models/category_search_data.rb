class CategorySearchData < ActiveRecord::Base
  belongs_to :category

  validates_presence_of :search_data
end

# == Schema Information
#
# Table name: category_search_data
#
#  category_id :integer          not null, primary key
#  search_data :tsvector
#
# Indexes
#
#  idx_search_category  (search_data)
#

