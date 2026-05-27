# frozen_string_literal: true

module DiscourseAi
  # A cache layer on top of our topic summarization engine. Also handle permissions.
  class TopicSummarization
    def self.for(topic, user)
      new(DiscourseAi::Summarization.topic_summary(topic), user)
    end

    def initialize(summarizer, user)
      @summarizer = summarizer
      @user = user
    end

    def cached_summary
      return if summarizer.nil?

      summarizer.existing_summary
    end

    def summarize(skip_age_check: false, &on_partial_blk)
      # Existing summary shouldn't be nil in this scenario because the controller checks its existence.
      return if !user && !cached_summary

      can_summarize = Guardian.new(user).can_request_summary?
      return if !can_summarize && cached_summary&.outdated

      return cached_summary if use_cached?(skip_age_check)

      summarizer.delete_cached_summaries! if cached_summary

      summarizer.summarize(user, &on_partial_blk)
    end

    private

    attr_reader :summarizer, :user

    def use_cached?(skip_age_check)
      return false if !cached_summary

      can_summarize = Guardian.new(user).can_request_summary?
      return true if !can_summarize

      return true if !cached_summary.outdated

      # If staleness is due to edited content, regenerate immediately.
      return false if outdated_due_to_post_edit?

      !skip_age_check && cached_summary.created_at >= 1.hour.ago
    end

    def outdated_due_to_post_edit?
      return false if !cached_summary.outdated

      fingerprint = summarizer.strategy.summary_fingerprint
      return false if fingerprint.blank?

      highest_target_unchanged =
        cached_summary.highest_target_number == summarizer.strategy.highest_target_number
      edited_since_summary = fingerprint[:latest_version_at]&.> cached_summary.updated_at

      highest_target_unchanged && edited_since_summary
    end
  end
end
