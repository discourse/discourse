# frozen_string_literal: true

# Post and topic attributes are only included when the `allowed_user_badge_topic_ids` option is provided. The caller of the
# serializer is responsible for ensuring that the topic ids in the options can be seen by the scope of the user by passing
# the result of `Guardian#can_see_topic_ids` to the `allowed_user_badge_topic_ids` option.
module UserBadgePostAndTopicAttributesMixin
  private

  def include_post_attributes?
    return false if !object.badge.show_posts || !object.post
    return true if scope.is_admin?

    allowed_user_badge_topic_ids = options[:allowed_user_badge_topic_ids]

    return false if allowed_user_badge_topic_ids.blank?

    topic_id = object.post.topic_id

    return false if topic_id.blank?

    allowed_user_badge_topic_ids.include?(topic_id)
  end

  def include_topic_attributes?
    include_post_attributes? && object.post.topic
  end
end
