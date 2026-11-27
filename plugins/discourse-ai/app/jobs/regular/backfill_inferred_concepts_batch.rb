# frozen_string_literal: true

module Jobs
  class BackfillInferredConceptsBatch < ::Jobs::Base
    sidekiq_options queue: "low", retry: false

    DEFAULT_CONCURRENCY = 5
    MAX_CONSECUTIVE_FAILURES = 3
    FEATURE_NAME = DiscourseAi::InferredConcepts::DecisionMatcher::FEATURE_NAME

    def execute(args = {})
      args = (args || {}).with_indifferent_access
      topic_ids = Array(args[:topic_ids]).map(&:to_i).uniq.select(&:positive?)
      return if topic_ids.empty?

      return unless SiteSetting.discourse_ai_enabled
      return unless SiteSetting.inferred_concepts_enabled && DiscourseAi::Embeddings.enabled?
      return unless InferredConcept.active.exists?
      return if DiscourseAi::InferredConcepts::Seeder.seeding?

      decision_model = DiscourseAi::InferredConcepts::DecisionMatcher.decision_model
      agent_class =
        (
          if decision_model
            nil
          else
            DiscourseAi::InferredConcepts::Classifier.resolve_agent(allow_new: false)&.class
          end
        )
      llm =
        (
          if decision_model || agent_class.nil?
            nil
          else
            DiscourseAi::InferredConcepts::Classifier.resolve_llm(
              allow_new: false,
              agent: agent_class.new,
            )
          end
        )
      return if decision_model.nil? && llm.nil?

      unless credits_available?(decision_model, llm)
        Rails.logger.info(
          "Inferred concepts backfill batch skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      applier = DiscourseAi::InferredConcepts::Applier.new
      retriever = DiscourseAi::InferredConcepts::CandidateRetriever.new
      candidate_limit =
        (
          if decision_model
            DiscourseAi::InferredConcepts::DecisionMatcher::MAX_CANDIDATES
          else
            DiscourseAi::InferredConcepts::CandidateRetriever::DEFAULT_LIMIT
          end
        )

      work_items = prepare_batch(topic_ids, applier:, retriever:, candidate_limit:)
      return if work_items.empty?

      concurrency = (args[:concurrency] || DEFAULT_CONCURRENCY).to_i.clamp(1, 20)
      pool =
        if concurrency > 1 && work_items.size > 1
          Scheduler::ThreadPool.new(min_threads: 0, max_threads: concurrency, idle_time: 30)
        end

      outcomes =
        begin
          classify_batch(work_items, pool:, decision_model:, agent_class:, llm:)
        ensure
          if pool
            pool.shutdown
            pool.wait_for_termination(timeout: 30)
          end
        end

      apply_outcomes(outcomes, applier:)
    ensure
      release_inflight(topic_ids)
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

    def release_inflight(topic_ids)
      return if topic_ids.blank?

      Discourse.redis.zrem(Jobs::InferredConceptsBackfill::INFLIGHT_KEY, topic_ids.map(&:to_s))
    end

    def prepare_batch(topic_ids, applier:, retriever:, candidate_limit:)
      topics_by_id = Topic.where(id: topic_ids).includes(:category, :tags).index_by(&:id)
      already_tagged =
        InferredConceptTopic.where(topic_id: topic_ids).distinct.pluck(:topic_id).to_set
      work_items = []

      topic_ids.each do |topic_id|
        topic = topics_by_id[topic_id]
        if topic.blank? || topic.deleted_at.present? || !topic.visible || topic.private_message?
          next
        end
        next if already_tagged.include?(topic.id)

        content = applier.topic_content_for_analysis(topic)
        if content.blank?
          mark_no_match(topic.id, "")
          next
        end

        digest = applier.content_digest(content)
        candidates =
          retriever.retrieve(
            content: content,
            target: topic,
            limit: candidate_limit,
            active_only: true,
            require_stored_embedding: true,
          )
        next if candidates.empty?

        work_items << { topic:, content:, digest:, candidates: }
      rescue StandardError => e
        Discourse.warn_exception(
          e,
          message: "Failed preparing topic #{topic_id} for inferred concepts backfill",
        )
      end

      work_items
    end

    def classify_batch(work_items, pool:, decision_model:, agent_class:, llm:)
      state_mutex = Mutex.new
      halted = false
      consecutive_failures = 0

      run_item = ->(item) do
        should_skip = state_mutex.synchronize { halted }
        return { item:, matches: [], error: nil, skipped: true } if should_skip

        matches = classify_item(item, decision_model:, agent_class:, llm:)

        state_mutex.synchronize { consecutive_failures = 0 }
        { item:, matches:, error: nil, skipped: false }
      rescue DiscourseAi::Decisions::CreditLimitExceeded,
             LlmCreditAllocation::CreditLimitExceeded => e
        state_mutex.synchronize { halted = true }
        { item:, matches: [], error: e, skipped: false }
      rescue StandardError => e
        state_mutex.synchronize do
          consecutive_failures += 1
          halted = true if consecutive_failures >= MAX_CONSECUTIVE_FAILURES
        end
        { item:, matches: [], error: e, skipped: false }
      end

      return work_items.map { |item| run_item.call(item) } if pool.nil? || work_items.size <= 1

      results = Queue.new
      work_items.each { |item| pool.post { results << run_item.call(item) } }
      Array.new(work_items.size) { results.pop }
    end

    def classify_item(item, decision_model:, agent_class:, llm:)
      if decision_model
        result =
          DiscourseAi::InferredConcepts::DecisionMatcher.new(decision_model).match(
            item[:content],
            candidates: item[:candidates],
          )
        if result[:all_refused]
          raise DiscourseAi::Decisions::RequestFailed,
                "Decision model refused all concept questions"
        end
        result[:matches]
      else
        LlmCreditAllocation.check_credits!(llm, FEATURE_NAME)
        DiscourseAi::InferredConcepts::Classifier.new.classify(
          item[:content],
          candidates: item[:candidates],
          allow_new: false,
          agent: agent_class.new,
          llm: llm,
          user: Discourse.system_user,
        )[
          :matches
        ]
      end
    end

    def apply_outcomes(outcomes, applier:)
      credit_logged = false

      outcomes.each do |outcome|
        next if outcome[:skipped]

        item = outcome[:item]
        error = outcome[:error]

        if error.is_a?(DiscourseAi::Decisions::CreditLimitExceeded) ||
             error.is_a?(LlmCreditAllocation::CreditLimitExceeded)
          if !credit_logged
            credit_logged = true
            Rails.logger.info(
              "Inferred concepts backfill paused: credit limit exceeded. Will resume when credits reset.",
            )
          end
          next
        end

        if error
          Discourse.warn_exception(
            error,
            message: "Failed to backfill inferred concepts for topic #{item[:topic].id}",
          )
          next
        end

        matches = outcome[:matches]
        if matches.blank?
          mark_no_match(item[:topic].id, item[:digest])
          next
        end

        by_id = item[:candidates].index_by(&:id)
        match_entries =
          matches.filter_map do |match|
            concept = by_id[match[:concept_id]]
            next if concept.nil?

            { concept:, relevance: match[:relevance], primary: match[:primary] }
          end

        if match_entries.empty?
          mark_no_match(item[:topic].id, item[:digest])
        else
          applier.apply_matches_to_topic(item[:topic], match_entries, digest: item[:digest])
        end
      end
    end

    def mark_no_match(topic_id, digest)
      TopicCustomField.find_or_initialize_by(
        topic_id: topic_id,
        name: DiscourseAi::InferredConcepts::Applier::NO_MATCH_CUSTOM_FIELD,
      ).update!(value: digest.to_s)
    end
  end
end
