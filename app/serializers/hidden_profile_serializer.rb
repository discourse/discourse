# frozen_string_literal: true

class HiddenProfileSerializer < BasicUserSerializer
  attributes(:profile_hidden?, :title, :primary_group_name, :can_send_private_message_to_user)

  def profile_hidden?
    true
  end

  def can_send_private_message_to_user
    scope.can_send_private_message?(object)
  end

  def primary_group_name
    object.primary_group.try(:name)
  end
end
