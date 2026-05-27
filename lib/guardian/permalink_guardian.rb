# frozen_string_literal: true

module PermalinkGuardian
  def can_see_permalink_target?(permalink)
    return true if permalink.external?
    return can_see_topic?(permalink.topic) if permalink.topic_id.present?
    return can_see_post?(permalink.post) if permalink.post_id.present?
    return can_see_category?(permalink.category) if permalink.category_id.present?
    return can_see_tag?(permalink.tag) if permalink.tag_id.present?
    return can_see_user?(permalink.user) if permalink.user_id.present?
    false
  end
end
