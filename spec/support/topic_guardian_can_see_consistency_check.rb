# frozen_string_literal: true

# Monkey patches `TopicGuardian#can_see_topic?` to ensure that `TopicGuardian#can_see_topic_ids` returns the same
# result for the same inputs. We're using this check to bridge the transition to `TopicGuardian#can_see_topic_ids` as the
# backing implementation for `TopicGuardian#can_see_topic?` in the near future.
module TopicGuardianCanSeeConsistencyCheck
  extend ActiveSupport::Concern

  module ClassMethods
    def enable_can_see_consistency_check_called
      @enable_can_see_consistency_check_called = true
    end

    def enable_can_see_consistency_check_called?
      @enable_can_see_consistency_check_called
    end

    def can_see_consistency_check_was_enabled?
      @enable_can_see_consistency_check_was_enabled
    end

    def enable_topic_can_see_consistency_check
      @enable_can_see_consistency_check_was_enabled = true
      @enable_can_see_consistency_check = true
    end

    def disable_topic_can_see_consistency_check
      @enable_can_see_consistency_check = false
    end

    def run_topic_can_see_consistency_check?
      @enable_can_see_consistency_check
    end
  end

  def can_see_topic?(topic, hide_deleted = true)
    result = super

    if self.class.run_topic_can_see_consistency_check?
      new_result = self.can_see_topic_ids(topic_ids: [topic&.id], hide_deleted: hide_deleted).present?

      if result != new_result
        raise "result between TopicGuardian#can_see_topic? (#{result}) and TopicGuardian#can_see_topic_ids (#{new_result}) has drifted and returned different results for the same input"
      end

      self.class.enable_can_see_consistency_check_called
    end

    result
  end
end

class Guardian
  include TopicGuardianCanSeeConsistencyCheck
end
