# frozen_string_literal: true
class GroupAssociatedGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :associated_group

  after_commit :add_associated_users, on: [:create, :update]
  before_destroy :remove_associated_users

  def add_associated_users
    DistributedMutex.synchronize("group_associated_group_#{group_id}_#{associated_group_id}") do
      associated_group.users.in_batches do |users|
        users.each do |user|
          group.add_automatically(user, subject: associated_group.label)
        end
      end
    end
  end

  def remove_associated_users
    DistributedMutex.synchronize("group_associated_group_#{group_id}_#{associated_group_id}") do
      User.where("(
        SELECT COUNT(user_id)
        FROM user_associated_groups AS uag
        WHERE uag.user_id = users.id
        AND uag.associated_group_id IN (
          SELECT associated_group_id FROM group_associated_groups AS gag
          WHERE gag.group_id = ?
        )
      ) = 1", group.id).in_batches do |users|
        users.each do |user|
          group.remove_automatically(user, subject: associated_group.label)
        end
      end
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
