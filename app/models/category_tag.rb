# frozen_string_literal: true

class CategoryTag < ActiveRecord::Base
  belongs_to :category
  belongs_to :tag

  after_commit { Site.clear_cache }
end

# == Schema Information
#
# Table name: category_tags
#
#  id          :integer          not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  category_id :integer          not null
#  tag_id      :integer          not null
#
# Indexes
#
#  idx_category_tags_ix1  (category_id,tag_id) UNIQUE
#  idx_category_tags_ix2  (tag_id,category_id) UNIQUE
#
