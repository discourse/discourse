# frozen_string_literal: true

module StaffActionLogGuardian
  def can_see_staff_action_log?(user_history)
    return true if is_admin?
    return false unless is_staff?
    UserHistory.moderator_visible_action_ids.include?(user_history.action)
  end

  def can_see_staff_action_log_content?(user_history)
    return true if is_admin?
    return false if user_history.topic_id.present? && !can_see_topic?(user_history.topic)
    return false if user_history.post_id.present? && !can_see_post?(user_history.post)
    return false if user_history.category_id.present? && !can_see_category?(user_history.category)
    true
  end
end
