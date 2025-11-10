# frozen_string_literal: true

class HiddenProfileSerializer < BasicUserSerializer
  attr_accessor :topic_post_count

  attributes(
    :profile_hidden?,
    :title,
    :topic_post_count,
    :primary_group_name,
    :can_send_private_message_to_user,
  )

  def profile_hidden?
    true
  end

  def can_send_private_message_to_user
    scope.can_send_private_message?(object)
  end

  def primary_group_name
    object.primary_group.try(:name)
  end

  def include_topic_post_count?
    topic_post_count.present?
  end
end
