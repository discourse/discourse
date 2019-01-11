class PostSearchData < ActiveRecord::Base
  include HasSearchData
end

# == Schema Information
#
# Table name: post_search_data
#
#  post_id     :integer          not null, primary key
#  search_data :tsvector
#  raw_data    :text
#  locale      :string
#  version     :integer          default(0)
#
# Indexes
#
#  idx_search_post  (search_data) USING gin
#
