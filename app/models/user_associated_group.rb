# frozen_string_literal: true

class UserAssociatedGroup < ActiveRecord::Base
  belongs_to :user
  belongs_to :associated_group

  after_commit :add_to_associated_groups, on: [:create, :update]
  before_destroy :remove_from_associated_groups

  def add_to_associated_groups
    associated_group.groups.each do |group|
      group.add_automatically(user, subject: associated_group.label)
    end
  end

  def remove_from_associated_groups
    Group.where("NOT EXISTS(
      SELECT 1
      FROM user_associated_groups uag
      JOIN group_associated_groups gag
      ON gag.associated_group_id = uag.associated_group_id
      WHERE uag.user_id = :user_id
      AND uag.id != :uag_id
      AND gag.group_id = groups.id
    )", uag_id: id, user_id: user_id).each do |group|
      group.remove_automatically(user, subject: associated_group.label)
    end
  end
end

# == Schema Information
#
# Table name: user_associated_groups
#
#  id                  :bigint           not null, primary key
#  user_id             :bigint           not null
#  associated_group_id :bigint           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_user_associated_groups                         (user_id,associated_group_id) UNIQUE
#  index_user_associated_groups_on_associated_group_id  (associated_group_id)
#  index_user_associated_groups_on_user_id              (user_id)
#
