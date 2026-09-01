# frozen_string_literal: true

class ::TopicAssigner
  class << self
    def backfill_auto_assign
      deprecation_note
      Assigner.backfill_auto_assign
    end

    def assigned_self?(text)
      deprecation_note
      Assigner.assigned_self?(text)
    end

    def auto_assign(post, force: false)
      deprecation_note
      Assigner.auto_assign(post, force: force)
    end

    def is_last_staff_post?(post)
      deprecation_note
      Assigner.is_last_staff_post?(post)
    end

    def mentioned_staff(post)
      deprecation_note
      Assigner.mentioned_staff(post)
    end

    def publish_topic_tracking_state(topic, user_id)
      deprecation_note
      Assigner.publish_topic_tracking_state(topic, user_id)
    end
  end

  class << self
    def deprecation_note
      Discourse.deprecate(
        "TopicAssigner class is deprecated, use Assigner",
        since: "2.8",
        drop_from: "2.9",
      )
    end
  end
  def initialize(target, user)
    self.class.deprecation_note
    Assigner.new(target, user)
  end
end
