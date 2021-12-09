# frozen_string_literal: true
class GroupAssociatedGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :associated_group

  after_commit :add_associated_users, on: [:create, :update]
  before_destroy :remove_associated_users

  def add_associated_users
    with_mutex do
      associated_group.users.in_batches do |users|
        users.each do |user|
          group.add_automatically(user, subject: associated_group.label)
        end
      end
    end
  end

  def remove_associated_users
    with_mutex do
      User.where("NOT EXISTS(
        SELECT 1
        FROM user_associated_groups uag
        JOIN group_associated_groups gag
        ON gag.associated_group_id = uag.associated_group_id
        WHERE uag.user_id = users.id
        AND gag.id != :gag_id
        AND gag.group_id = :group_id
      )", gag_id: id, group_id: group_id).in_batches do |users|
        users.each do |user|
          group.remove_automatically(user, subject: associated_group.label)
        end
      end
    end
  end

  private

  def with_mutex
    DistributedMutex.synchronize("group_associated_group_#{group_id}_#{associated_group_id}") do
      yield
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
