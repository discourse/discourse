class TopicSearchData < ActiveRecord::Base
  include HasSearchData
end

# == Schema Information
#
# Table name: topic_search_data
#
#  topic_id    :integer          not null, primary key
#  raw_data    :text
#  locale      :string           not null
#  search_data :tsvector
#  version     :integer          default(0)
#
# Indexes
#
#  idx_search_topic  (search_data) USING gin
#
