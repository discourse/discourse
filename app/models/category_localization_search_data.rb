# frozen_string_literal: true

class CategoryLocalizationSearchData < ActiveRecord::Base
  include HasSearchData
end

# == Schema Information
#
# Table name: category_localization_search_data
#
#  locale                   :text
#  raw_data                 :text
#  search_data              :tsvector
#  version                  :integer          default(0)
#  category_localization_id :bigint           not null, primary key
#
# Indexes
#
#  idx_search_category_localization  (search_data) USING gin
#
