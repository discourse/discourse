# frozen_string_literal: true

class UserSearchData < ActiveRecord::Base
  include HasSearchData
end

# == Schema Information
#
# Table name: user_search_data
#
#  locale      :text
#  raw_data    :text
#  search_data :tsvector
#  version     :integer          default(0)
#  user_id     :integer          not null, primary key
#
# Indexes
#
#  idx_search_user  (search_data) USING gin
#
