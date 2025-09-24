# frozen_string_literal: true

class BasicGroupUserSerializer < ApplicationSerializer
  attributes :group_id, :user_id, :notification_level, :owner

  def include_owner?
    object.user_id == scope&.user&.id
  end

  def owner
    # Owner is now stored in group_owners table, separate from membership
    GroupOwner.exists?(group_id: object.group_id, user_id: object.user_id)
  end
end
