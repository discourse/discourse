# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Seeder
      STATE_KEY = "discourse_ai:inferred_concepts:seed_state"
      MUTEX_KEY = "discourse_ai_seed_inferred_concepts"
      MUTEX_VALIDITY = 6.hours
      STALE_AFTER = 1.hour
      TERMINAL_STATE_TTL = 24.hours
      RECENT_WINDOW = 2.years
      MIN_WORD_COUNT = 50
      MAX_SEED_TOPICS = 20_000
      WAVE_SIZE = 15
      DEFAULT_CONCURRENCY = 5
      INTERMEDIATE_CURATE_INTERVAL = 250

      def self.status
        raw = Discourse.redis.get(STATE_KEY)
        return nil if raw.blank?

        state = JSON.parse(raw)
        return nil if %w[queued running].include?(state["status"]) && stale?(state)

        state
      rescue JSON::ParserError
        nil
      end

      def self.seeding?
        state = status
        state.present? && %w[queued running].include?(state["status"])
      end

      def self.mark_queued!
        now = Time.zone.now.iso8601
        write_state(
          "status" => "queued",
          "queued_at" => now,
          "updated_at" => now,
          "processed" => 0,
          "total" => 0,
        )
      end

      def self.reset_status!
        Discourse.redis.del(STATE_KEY)
      end

      def self.write_state(state)
        ttl =
          %w[queued running].include?(state["status"]) ? STALE_AFTER.to_i : TERMINAL_STATE_TTL.to_i
        Discourse.redis.set(STATE_KEY, state.to_json, ex: ttl)
        state
      end
      private_class_method :write_state

      def self.stale?(state)
        timestamp = state["updated_at"] || state["started_at"] || state["queued_at"]
        return true if timestamp.blank?

        Time.zone.parse(timestamp.to_s) < STALE_AFTER.ago
      rescue ArgumentError
        true
      end
      private_class_method :stale?

      def initialize(
        concurrency: DEFAULT_CONCURRENCY,
        wave_size: WAVE_SIZE,
        curate_every: INTERMEDIATE_CURATE_INTERVAL
      )
        @concurrency = concurrency.to_i.clamp(1, 20)
        @wave_size = wave_size.to_i.clamp(1, 100)
        @curate_every = curate_every.to_i
      end

      def select_seed_topics(limit: SiteSetting.inferred_concepts_seed_topics_limit)
        target_limit = limit.to_i
        return [] if target_limit <= 0

        recent_ids =
          query_stratified_topic_ids(limit: target_limit, since: RECENT_WINDOW.ago, exclude_ids: [])
        return recent_ids if recent_ids.size >= target_limit

        remaining = target_limit - recent_ids.size
        older_ids =
          query_stratified_topic_ids(limit: remaining, since: nil, exclude_ids: recent_ids)
        recent_ids + older_ids
      end

      def seed!(limit: nil)
        return { "status" => "skipped" } unless can_seed?

        agent_class = Classifier.resolve_agent(allow_new: true)&.class
        llm = agent_class ? Classifier.resolve_llm(allow_new: true, agent: agent_class.new) : nil
        if agent_class.nil? || llm.nil?
          now = Time.zone.now.iso8601
          return(
            self.class.send(
              :write_state,
              "status" => "failed",
              "error" => I18n.t("discourse_ai.errors.no_default_llm"),
              "started_at" => now,
              "finished_at" => now,
              "updated_at" => now,
              "processed" => 0,
              "total" => 0,
              "concepts_created" => 0,
            )
          )
        end

        effective_limit =
          (limit || SiteSetting.inferred_concepts_seed_topics_limit).to_i.clamp(1, MAX_SEED_TOPICS)

        DistributedMutex.synchronize(MUTEX_KEY, validity: MUTEX_VALIDITY) do
          topic_ids = select_seed_topics(limit: effective_limit)
          started_at = Time.zone.now.iso8601
          initial_concepts = InferredConcept.count

          write_progress(
            "status" => "running",
            "started_at" => started_at,
            "updated_at" => started_at,
            "processed" => 0,
            "total" => topic_ids.size,
          )

          applier = Applier.new
          retriever = CandidateRetriever.new
          classifier = Classifier.new
          manager = Manager.new
          user = Discourse.system_user

          processed = 0
          since_last_curate = 0
          failed_error = nil

          pool =
            if @concurrency > 1 && topic_ids.size > 1
              Scheduler::ThreadPool.new(min_threads: 0, max_threads: @concurrency, idle_time: 30)
            end

          begin
            topic_ids.each_slice(@wave_size) do |wave_ids|
              unless LlmCreditAllocation.credits_available?(llm)
                failed_error =
                  I18n.t(
                    "discourse_ai.llm_credit_allocation.limit_exceeded_admin",
                    reset_time: llm.llm_credit_allocation&.relative_reset_time || "",
                  )
                break
              end

              work_items, skipped_count =
                prepare_wave(wave_ids, applier: applier, retriever: retriever)
              processed += skipped_count

              wave_outcomes =
                classify_wave(
                  work_items,
                  pool: pool,
                  classifier: classifier,
                  agent_class: agent_class,
                  llm: llm,
                  user: user,
                )

              wave_outcomes.each do |outcome|
                item = outcome[:item]
                error = outcome[:error]

                if error.is_a?(LlmCreditAllocation::CreditLimitExceeded)
                  failed_error ||= error.message
                elsif error
                  processed += 1
                  Discourse.warn_exception(
                    error,
                    message: "Failed seeding inferred concepts for topic #{item[:topic].id}",
                  )
                else
                  manager.apply_classification_result(
                    item[:topic],
                    outcome[:result],
                    candidates: item[:candidates],
                    digest: item[:digest],
                    allow_new: true,
                    applier: applier,
                  )
                  processed += 1
                  since_last_curate += 1
                end
              end

              flush_concept_embeddings

              if failed_error.nil? && @curate_every > 0 && since_last_curate >= @curate_every &&
                   processed < topic_ids.size
                curate_seeded_concepts
                since_last_curate = 0
              end

              write_progress(
                "status" => "running",
                "started_at" => started_at,
                "updated_at" => Time.zone.now.iso8601,
                "processed" => processed,
                "total" => topic_ids.size,
              )

              break if failed_error.present?
            end
          ensure
            if pool
              pool.shutdown
              pool.wait_for_termination(timeout: 30)
            end
          end

          flush_concept_embeddings
          curate_seeded_concepts if since_last_curate > 0

          now = Time.zone.now.iso8601
          final_state = {
            "status" => failed_error ? "failed" : "completed",
            "started_at" => started_at,
            "finished_at" => now,
            "updated_at" => now,
            "processed" => processed,
            "total" => topic_ids.size,
            "concepts_created" => [InferredConcept.count - initial_concepts, 0].max,
          }
          final_state["error"] = failed_error if failed_error.present?

          self.class.send(:write_state, final_state)
        end
      end

      private

      def can_seed?
        SiteSetting.inferred_concepts_enabled && DiscourseAi::Embeddings.enabled?
      end

      def prepare_wave(wave_ids, applier:, retriever:)
        topics_by_id = Topic.where(id: wave_ids).includes(:category, :tags).index_by(&:id)
        work_items = []
        skipped_count = 0

        wave_ids.each do |topic_id|
          topic = topics_by_id[topic_id]
          next if topic.blank? || topic.deleted_at.present? || topic.private_message?

          content = applier.topic_content_for_analysis(topic)
          if content.blank?
            skipped_count += 1
            next
          end

          digest = applier.content_digest(content)
          if InferredConceptTopic.where(topic_id: topic.id, digest: digest).exists?
            skipped_count += 1
            next
          end

          candidates = retriever.retrieve(content: content, target: topic)
          work_items << { topic:, content:, digest:, candidates: }
        rescue CandidateRetriever::EmbeddingsUnavailableError,
               DiscourseAi::Embeddings::ProviderPausedError,
               DiscourseAi::Inference::EmbeddingInferenceError => e
          skipped_count += 1
          Discourse.warn_exception(
            e,
            message: "Failed retrieving candidates while seeding topic #{topic_id}",
          )
        end

        [work_items, skipped_count]
      end

      def classify_wave(work_items, pool:, classifier:, agent_class:, llm:, user:)
        return [] if work_items.empty?

        if pool.nil? || work_items.size <= 1
          return(
            work_items.map do |item|
              result =
                classifier.classify(
                  item[:content],
                  candidates: item[:candidates],
                  allow_new: true,
                  agent: agent_class.new,
                  llm: llm,
                  user: user,
                )
              { item:, result:, error: nil }
            rescue StandardError => e
              { item:, result: nil, error: e }
            end
          )
        end

        results = Queue.new
        work_items.each do |item|
          pool.post do
            result =
              classifier.classify(
                item[:content],
                candidates: item[:candidates],
                allow_new: true,
                agent: agent_class.new,
                llm: llm,
                user: user,
              )
            results << { item:, result:, error: nil }
          rescue StandardError => e
            results << { item:, result: nil, error: e }
          end
        end

        Array.new(work_items.size) { results.pop }
      end

      def query_stratified_topic_ids(limit:, since:, exclude_ids:)
        conditions = [
          "t.archetype = :archetype",
          "t.deleted_at IS NULL",
          "t.visible = true",
          "t.word_count >= :min_words",
          "NOT EXISTS (SELECT 1 FROM inferred_concept_topics ict WHERE ict.topic_id = t.id)",
        ]
        params = { archetype: Archetype.default, min_words: MIN_WORD_COUNT, limit: limit }

        if since.present?
          conditions << "t.created_at >= :since"
          params[:since] = since
        end

        if exclude_ids.present?
          conditions << "t.id NOT IN (:exclude_ids)"
          params[:exclude_ids] = exclude_ids
        end

        DB.query_single(<<~SQL, **params)
          SELECT id
          FROM (
            SELECT
              t.id,
              (t.like_count * 2 + t.posts_count * 3 + t.views * 0.1) AS engagement_score,
              ROW_NUMBER() OVER (
                PARTITION BY t.category_id
                ORDER BY (t.like_count * 2 + t.posts_count * 3 + t.views * 0.1) DESC, t.id DESC
              ) AS category_rank
            FROM topics t
            WHERE #{conditions.join(" AND ")}
          ) ranked
          ORDER BY category_rank ASC, engagement_score DESC, id DESC
          LIMIT :limit
        SQL
      end

      def write_progress(state)
        self.class.send(:write_state, state)
      end

      def flush_concept_embeddings
        return unless DiscourseAi::Embeddings.enabled?

        model_id = SiteSetting.ai_embeddings_selected_model.to_i
        table = DiscourseAi::Embeddings::Schema::INFERRED_CONCEPTS_TABLE
        unembedded_ids =
          InferredConcept
            .where.not(status: :retired)
            .where(
              "NOT EXISTS (SELECT 1 FROM #{table} e WHERE e.inferred_concept_id = inferred_concepts.id AND e.model_id = :model_id)",
              model_id: model_id,
            )
            .pluck(:id)
        return if unembedded_ids.empty?

        DiscourseAi::Embeddings::Vector.instance.gen_bulk_reprensentations(
          InferredConcept.where(id: unembedded_ids),
        )
      rescue StandardError => e
        Discourse.warn_exception(e, message: "Failed embedding inferred concepts during seed")
      end

      def curate_seeded_concepts
        return unless InferredConcept.where.not(status: :retired).exists?

        Curator.new.curate!
      rescue StandardError => e
        Discourse.warn_exception(e, message: "Failed curating seeded inferred concepts")
      end
    end
  end
end
