class CategoryTagGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :tag_group
end

# == Schema Information
#
# Table name: category_tag_groups
#
#  id           :integer          not null, primary key
#  category_id  :integer          not null
#  tag_group_id :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  idx_category_tag_groups_ix1  (category_id,tag_group_id) UNIQUE
#
