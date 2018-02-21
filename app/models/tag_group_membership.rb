class TagGroupMembership < ActiveRecord::Base
  belongs_to :tag
  belongs_to :tag_group
end

# == Schema Information
#
# Table name: tag_group_memberships
#
#  id           :integer          not null, primary key
#  tag_id       :integer          not null
#  tag_group_id :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_tag_group_memberships_on_tag_group_id_and_tag_id  (tag_group_id,tag_id) UNIQUE
#
