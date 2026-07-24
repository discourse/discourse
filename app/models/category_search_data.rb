# frozen_string_literal: true

class CategorySearchData < ActiveRecord::Base
  include HasSearchData
end

# == Schema Information
#
# Table name: category_search_data
#
#  locale      :text
#  raw_data    :text
#  search_data :tsvector
#  version     :integer          default(0)
#  category_id :integer          not null, primary key
#
# Indexes
#
#  idx_search_category  (search_data) USING gin
#
