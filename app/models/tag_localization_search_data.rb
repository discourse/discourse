# frozen_string_literal: true

class TagLocalizationSearchData < ActiveRecord::Base
  include HasSearchData
end

# == Schema Information
#
# Table name: tag_localization_search_data
#
#  locale              :text
#  raw_data            :text
#  search_data         :tsvector
#  version             :integer          default(0)
#  tag_localization_id :bigint           not null, primary key
#
# Indexes
#
#  idx_search_tag_localization  (search_data) USING gin
#
