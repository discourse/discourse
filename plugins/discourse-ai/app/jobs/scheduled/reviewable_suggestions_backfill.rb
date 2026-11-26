# frozen_string_literal: true

module Jobs
  class ReviewableSuggestionsBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options queue: "low", retry: false
    cluster_concurrency 1

    BATCH_SIZE = 25
    MAX_CONSECUTIVE_FAILURES = 3

    def execute(_args)
      unless SiteSetting.discourse_ai_enabled &&
               SiteSetting.ai_reviewable_action_suggestions_enabled
        return
      end

      model = DecisionModel.find_by(id: SiteSetting.ai_reviewable_action_decision_model.presence)
      return unless model
      unless DecisionModelCreditAllocation.credits_available?(
               model,
               Jobs::SuggestReviewableAction::FEATURE_NAME,
             )
        return
      end

      reviewable_ids =
        Reviewable
          .pending
          .where
          .missing(:ai_reviewable_suggestion)
          .order(created_at: :desc, id: :desc)
          .limit(BATCH_SIZE)
          .pluck(:id)

      return if reviewable_ids.empty?

      suggest_job = Jobs::SuggestReviewableAction.new
      consecutive_failures = 0

      reviewable_ids.each do |reviewable_id|
        unless DecisionModelCreditAllocation.credits_available?(
                 model,
                 Jobs::SuggestReviewableAction::FEATURE_NAME,
               )
          break
        end

        begin
          suggest_job.execute(reviewable_id:)
          consecutive_failures = 0
        rescue DiscourseAi::Decisions::CreditLimitExceeded
          break
        rescue StandardError => e
          consecutive_failures += 1
          Discourse.warn_exception(
            e,
            message: "Failed to backfill reviewable suggestion for reviewable #{reviewable_id}",
          )
          break if consecutive_failures >= MAX_CONSECUTIVE_FAILURES
        end
      end
    end
  end
end
