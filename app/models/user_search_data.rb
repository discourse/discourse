# frozen_string_literal: true

class UserSearchData < ActiveRecord::Base
  include HasSearchData
end

# == Schema Information
#
# Table name: user_search_data
#
#  user_id     :integer          not null, primary key
#  search_data :tsvector
#  raw_data    :string(1000000)
#  locale      :string(10)
#  version     :integer          default(0)
#
# Indexes
#
#  idx_search_user  (search_data) USING gin
#
