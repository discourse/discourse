class BasicGroupUserSerializer < ApplicationSerializer
  attributes :group_id, :user_id, :notification_level, :owner

  def include_owner?
    object.user_id == scope&.user&.id
  end
end
