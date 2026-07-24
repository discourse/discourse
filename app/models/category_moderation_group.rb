# frozen_string_literal: true

class CategoryModerationGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :group
end

# == Schema Information
#
# Table name: category_moderation_groups
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  category_id :integer
#  group_id    :integer
#
# Indexes
#
#  index_category_moderation_groups_on_category_id_and_group_id  (category_id,group_id) UNIQUE
#
