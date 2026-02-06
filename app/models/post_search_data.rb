# frozen_string_literal: true

class PostSearchData < ActiveRecord::Base
  include HasSearchData
end

# == Schema Information
#
# Table name: post_search_data
#
#  locale          :string
#  private_message :boolean          not null
#  raw_data        :text
#  search_data     :tsvector
#  version         :integer          default(0)
#  post_id         :integer          not null, primary key
#
# Indexes
#
#  idx_search_post                                           (search_data) USING gin
#  index_post_search_data_on_post_id_and_version_and_locale  (post_id,version,locale)
#
