class PostSearchData < ActiveRecord::Base
  belongs_to :post

  validates_presence_of :search_data
end

# == Schema Information
#
# Table name: post_search_data
#
#  post_id     :integer          not null, primary key
#  search_data :tsvector
#  raw_data    :text
#  locale      :string
#
# Indexes
#
#  idx_search_post  (search_data)
#
