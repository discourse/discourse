class UserSearchData < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :search_data
end

# == Schema Information
#
# Table name: user_search_data
#
#  user_id     :integer          not null, primary key
#  search_data :tsvector
#  raw_data    :text
#  locale      :text
#
# Indexes
#
#  idx_search_user  (search_data)
#
