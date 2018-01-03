class TagSearchData < ActiveRecord::Base
  include HasSearchData
end

# == Schema Information
#
# Table name: tag_search_data
#
#  tag_id      :integer          not null, primary key
#  search_data :tsvector
#  raw_data    :text
#  locale      :text
#  version     :integer          default(0)
#
# Indexes
#
#  idx_search_tag  (search_data)
#
