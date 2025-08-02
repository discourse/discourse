# frozen_string_literal: true

class CategoryRequiredTagGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :tag_group

  validates :min_count, numericality: { only_integer: true, greater_than: 0 }

  after_commit { Site.clear_cache }
end

# == Schema Information
#
# Table name: category_required_tag_groups
#
#  id           :bigint           not null, primary key
#  category_id  :bigint           not null
#  tag_group_id :bigint           not null
#  min_count    :integer          default(1), not null
#  order        :integer          default(1), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  idx_category_required_tag_groups  (category_id,tag_group_id) UNIQUE
#
