# frozen_string_literal: true

class TagSearchData < ActiveRecord::Base
  include HasSearchData
end

# == Schema Information
#
# Table name: tag_search_data
#
#  locale      :text
#  raw_data    :text
#  search_data :tsvector
#  version     :integer          default(0)
#  tag_id      :integer          not null, primary key
#
# Indexes
#
#  idx_search_tag  (search_data) USING gin
#
