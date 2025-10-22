# frozen_string_literal: true

module Guardian::DiscourseAutomationGuardian
  def can_trigger_automation?(automation, topic)
    return false if automation.blank? || topic.blank?
    return false unless can_see_topic?(topic)

    allowed_groups = Array(automation.trigger_field("allowed_groups")["value"]).compact.map(&:to_i)
    return true if allowed_groups.blank?

    user_group_ids = user&.group_ids || []
    (user_group_ids & allowed_groups).any?
  end

  def ensure_can_trigger_automation!(automation, topic)
    raise Discourse::InvalidAccess unless can_trigger_automation?(automation, topic)
  end
end

Guardian.prepend Guardian::DiscourseAutomationGuardian
