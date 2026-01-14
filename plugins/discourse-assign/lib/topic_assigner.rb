# frozen_string_literal: true

class ::TopicAssigner
  def self.backfill_auto_assign
    deprecation_note
    Assigner.backfill_auto_assign
  end

  def self.assigned_self?(text)
    deprecation_note
    Assigner.assigned_self?(text)
  end

  def self.auto_assign(post, force: false)
    deprecation_note
    Assigner.auto_assign(post, force)
  end

  def self.is_last_staff_post?(post)
    deprecation_note
    Assigner.is_last_staff_post?(post)
  end

  def self.mentioned_staff(post)
    deprecation_note
    Assigner.mentioned_staff(post)
  end

  def self.publish_topic_tracking_state(topic, user_id)
    deprecation_note
    Assigner.publish_topic_tracking_state(topic, user_id)
  end

  def initialize(target, user)
    self.class.deprecation_note
    Assigner.new(target, user)
  end

  def self.deprecation_note
    Discourse.deprecate(
      "TopicAssigner class is deprecated, use Assigner",
      since: "2.8",
      drop_from: "2.9",
    )
  end
end
