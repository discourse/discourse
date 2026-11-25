# frozen_string_literal: true

module Jobs
  class InferredConceptsBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options queue: "low", retry: false
    cluster_concurrency 1

    CURSOR_KEY = "discourse_ai:inferred_concepts:backfill_cursor"
    MAX_CONSECUTIVE_FAILURES = 3

    def self.reset_cursor!
      Discourse.redis.del(CURSOR_KEY)
    end

    def execute(_args)
      return unless SiteSetting.discourse_ai_enabled
      return unless SiteSetting.inferred_concepts_enabled && DiscourseAi::Embeddings.enabled?

      base_budget = SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour
      return if base_budget <= 0
      return unless InferredConcept.active.exists?
      return if DiscourseAi::InferredConcepts::Seeder.seeding?

      decision_model = DiscourseAi::InferredConcepts::DecisionMatcher.decision_model
      llm =
        (
          if decision_model
            nil
          else
            DiscourseAi::InferredConcepts::Classifier.resolve_llm(allow_new: false)
          end
        )
      return if decision_model.nil? && llm.nil?

      unless credits_available?(decision_model, llm)
        Rails.logger.info(
          "Inferred concepts backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit_per_job = [base_budget, 12].max / 12
      topics = backfill_topics(limit: limit_per_job, cursor_id: current_cursor_id).to_a
      return if topics.empty?

      applier = DiscourseAi::InferredConcepts::Applier.new
      consecutive_failures = 0
      had_failure = false
      last_succeeded_id = nil

      topics.each do |topic|
        unless credits_available?(decision_model, llm)
          Rails.logger.info(
            "Inferred concepts backfill paused: insufficient credits. Will resume when credits reset.",
          )
          break
        end

        begin
          applier.match_existing_concepts(
            topic,
            active_only: true,
            require_stored_embedding: true,
            raise_on_error: true,
          )
          last_succeeded_id = topic.id unless had_failure
          consecutive_failures = 0
        rescue DiscourseAi::Decisions::CreditLimitExceeded, LlmCreditAllocation::CreditLimitExceeded
          Rails.logger.info(
            "Inferred concepts backfill paused: credit limit exceeded. Will resume when credits reset.",
          )
          break
        rescue StandardError => e
          had_failure = true
          consecutive_failures += 1
          Discourse.warn_exception(
            e,
            message: "Failed to backfill inferred concepts for topic #{topic.id}",
          )
          break if consecutive_failures >= MAX_CONSECUTIVE_FAILURES
        end
      end

      save_cursor(last_succeeded_id) if last_succeeded_id.present?
    end

    private

    def credits_available?(decision_model, llm)
      if decision_model
        DecisionModelCreditAllocation.credits_available?(
          decision_model,
          DiscourseAi::InferredConcepts::DecisionMatcher::FEATURE_NAME,
        )
      else
        LlmCreditAllocation.credits_available?(llm)
      end
    end

    def backfill_topics(limit:, cursor_id:)
      model_id = SiteSetting.ai_embeddings_selected_model.to_i
      table = DiscourseAi::Embeddings::Schema::TOPICS_TABLE
      max_age_days = SiteSetting.inferred_concepts_backfill_max_age_days
      min_words = SiteSetting.inferred_concepts_backfill_minimum_word_count

      scope =
        Topic
          .joins(
            "INNER JOIN #{table} ate ON ate.topic_id = topics.id AND ate.model_id = #{model_id}",
          )
          .where(archetype: Archetype.default, deleted_at: nil, visible: true)
          .where("topics.word_count >= ?", min_words)
          .where(
            "NOT EXISTS (SELECT 1 FROM inferred_concept_topics ict WHERE ict.topic_id = topics.id)",
          )

      scope = scope.where("topics.created_at >= ?", max_age_days.days.ago) if max_age_days > 0

      scope = scope.where("topics.id < ?", cursor_id) if cursor_id.present?
      scope.order("topics.id DESC").limit(limit)
    end

    def current_cursor_id
      raw = Discourse.redis.get(CURSOR_KEY)
      raw.presence&.to_i
    end

    def save_cursor(topic_id)
      Discourse.redis.set(CURSOR_KEY, topic_id.to_s)
    end
  end
end
