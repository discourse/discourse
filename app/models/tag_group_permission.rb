# frozen_string_literal: true

# Who can see and use tags belonging to a tag group.
class TagGroupPermission < ActiveRecord::Base
  belongs_to :tag_group
  belongs_to :group

  def self.permission_types
    @permission_types ||= Enum.new(full: 1, readonly: 3)
  end
end

# == Schema Information
#
# Table name: tag_group_permissions
#
#  id              :bigint           not null, primary key
#  tag_group_id    :bigint           not null
#  group_id        :bigint           not null
#  permission_type :integer          default(1), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_tag_group_permissions_on_group_id      (group_id)
#  index_tag_group_permissions_on_tag_group_id  (tag_group_id)
#
