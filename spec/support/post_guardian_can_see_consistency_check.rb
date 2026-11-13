# frozen_string_literal: true

module PostGuardianCanSeeConsistencyCheck
  extend ActiveSupport::Concern

  module ClassMethods
    def enable_post_can_see_consistency_check
      @enable_post_can_see_consistency_check = true
    end

    def disable_post_can_see_consistency_check
      @enable_post_can_see_consistency_check = false
    end

    def run_post_can_see_consistency_check?
      @enable_post_can_see_consistency_check
    end
  end

  def can_see_post?(post)
    result = super

    # Object permissions can inspect unsaved state which a SQL relation cannot see.
    topic_association = post&.association(:topic)
    topic = topic_association.target if topic_association&.loaded?
    persisted_state =
      !post ||
        (
          post.persisted? && !post.has_changes_to_save? &&
            (!topic || (topic.persisted? && !topic.has_changes_to_save?))
        )
    if self.class.run_post_can_see_consistency_check? && persisted_state
      scoped_result = Post.with_deleted.secured(self).exists?(id: post&.id)
      if result != scoped_result
        raise "Guardian#can_see_post? (#{result}) and Post.secured (#{scoped_result}) disagree for post #{post&.id}"
      end
    end

    result
  end
end

class Guardian
  prepend PostGuardianCanSeeConsistencyCheck
end
