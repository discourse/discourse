# frozen_string_literal: true

module Jobs
  class InferredConceptsBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options queue: "low", retry: false
    cluster_concurrency 1

    BATCH_SIZE = 15
    INFLIGHT_KEY = "discourse_ai:inferred_concepts:backfill_inflight"
    INFLIGHT_TTL = 10.minutes
    NO_MATCH_CUSTOM_FIELD = DiscourseAi::InferredConcepts::Applier::NO_MATCH_CUSTOM_FIELD
    FEATURE_NAME = DiscourseAi::InferredConcepts::DecisionMatcher::FEATURE_NAME

    def self.reset_inflight!
      Discourse.redis.del(INFLIGHT_KEY)
    end

    def execute(_args)
      return unless SiteSetting.discourse_ai_enabled
      return unless SiteSetting.inferred_concepts_enabled && DiscourseAi::Embeddings.enabled?

      DiscourseAi::InferredConcepts::Seeder.resume_if_stalled!

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
      inflight_ids = active_inflight_ids
      remaining_slots = limit_per_job - inflight_ids.size
      return if remaining_slots <= 0

      topic_ids = backfill_topic_ids(limit: remaining_slots, exclude_ids: inflight_ids)
      return if topic_ids.empty?

      claim_inflight_topics(topic_ids)
      topic_ids.each_slice(BATCH_SIZE) do |batch|
        Jobs.enqueue(:backfill_inferred_concepts_batch, topic_ids: batch)
      end
    end

    private

    def credits_available?(decision_model, llm)
      if decision_model
        DecisionModelCreditAllocation.check_credits!(decision_model, FEATURE_NAME)
      else
        LlmCreditAllocation.check_credits!(llm, FEATURE_NAME)
      end
      true
    rescue DiscourseAi::Decisions::CreditLimitExceeded, LlmCreditAllocation::CreditLimitExceeded
      false
    end

    def active_inflight_ids
      now = Time.now.to_f
      Discourse.redis.zremrangebyscore(INFLIGHT_KEY, "-inf", now)
      Discourse.redis.zrange(INFLIGHT_KEY, 0, -1).map(&:to_i)
    end

    def claim_inflight_topics(topic_ids)
      expires_at = Time.now.to_f + INFLIGHT_TTL.to_i
      Discourse.redis.multi do |tx|
        topic_ids.each { |id| tx.zadd(INFLIGHT_KEY, expires_at, id.to_s) }
        tx.expire(INFLIGHT_KEY, (INFLIGHT_TTL + 5.minutes).to_i)
      end
    end

    def backfill_topic_ids(limit:, exclude_ids:)
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
          .where(
            "NOT EXISTS (SELECT 1 FROM topic_custom_fields tcf WHERE tcf.topic_id = topics.id AND tcf.name = :no_match_field)",
            no_match_field: NO_MATCH_CUSTOM_FIELD,
          )

      scope = scope.where("topics.created_at >= ?", max_age_days.days.ago) if max_age_days > 0
      scope = scope.where.not(id: exclude_ids) if exclude_ids.present?

      scope.order(Arel.sql("topics.last_posted_at DESC, topics.id DESC")).limit(limit).pluck(:id)
    end
  end
end
