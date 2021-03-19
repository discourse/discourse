# frozen_string_literal: true
class GroupAssociatedGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :associated_group

  after_create do
    associated_group.users.each do |user|
      group.add_automatically(user, subject: associated_group.label)
    end
  end

  after_destroy do
    associated_group.users.each do |user|
      group.remove_automatically(user, subject: associated_group.label)
    end
  end
end

# == Schema Information
#
# Table name: group_associated_groups
#
#  id                  :bigint           not null, primary key
#  group_id            :bigint           not null
#  associated_group_id :bigint           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_group_associated_groups                         (group_id,associated_group_id) UNIQUE
#  index_group_associated_groups_on_associated_group_id  (associated_group_id)
#  index_group_associated_groups_on_group_id             (group_id)
#
