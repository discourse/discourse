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
      summarizer.existing_summary
    end

    def summarize(skip_age_check: false, &on_partial_blk)
      # Existing summary shouldn't be nil in this scenario because the controller checks its existence.
      return if !user && !cached_summary

      return cached_summary if use_cached?(skip_age_check)

      summarizer.delete_cached_summaries! if cached_summary

      summarizer.summarize(user, &on_partial_blk)
    end

    private

    attr_reader :summarizer, :user

    def use_cached?(skip_age_check)
      can_summarize = Guardian.new(user).can_request_summary?

      cached_summary &&
        !(
          can_summarize && cached_summary.outdated &&
            (skip_age_check || cached_summary.created_at < 1.hour.ago)
        )
    end
  end
end
