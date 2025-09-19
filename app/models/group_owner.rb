# frozen_string_literal: true

class GroupOwner < ActiveRecord::Base
  belongs_to :group
  belongs_to :user

  validates :group_id, uniqueness: { scope: :user_id }

  after_commit :trigger_owner_added_event, on: [:create]
  after_commit :trigger_owner_removed_event, on: [:destroy]

  private

  def trigger_owner_added_event
    DiscourseEvent.trigger(:user_added_as_group_owner, user, group)
  end

  def trigger_owner_removed_event
    DiscourseEvent.trigger(:user_removed_as_group_owner, user, group)
  end
end

# == Schema Information
#
# Table name: group_owners
#
#  id         :integer          not null, primary key
#  group_id    :integer          not null
#  user_id     :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_group_owners_on_group_id_and_user_id  (group_id,user_id) UNIQUE
#  index_group_owners_on_user_id_and_group_id  (user_id,group_id) UNIQUE
#
