# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Seeder
      STATE_KEY = "discourse_ai:inferred_concepts:seed_state"
      QUEUE_KEY = "discourse_ai:inferred_concepts:seed_queue"
      MUTEX_KEY = "discourse_ai_seed_inferred_concepts"
      MUTEX_VALIDITY = 5.minutes
      STALE_AFTER = 1.hour
      WAVE_STALE_AFTER = 5.minutes
      QUEUE_TTL = 24.hours
      TERMINAL_STATE_TTL = 24.hours
      RECENT_WINDOW = 2.years
      MIN_WORD_COUNT = 50
      MAX_SEED_TOPICS = 20_000
      WAVE_SIZE = 15
      DEFAULT_CONCURRENCY = 5
      INTERMEDIATE_CURATE_INTERVAL = 250
      FEATURE_NAME = "inferred_concepts_generate"

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
        Discourse.redis.del(QUEUE_KEY)
        write_state(
          "status" => "queued",
          "run_id" => SecureRandom.hex(8),
          "queued_at" => now,
          "updated_at" => now,
          "processed" => 0,
          "total" => 0,
        )
      end

      def self.reset_status!
        Discourse.redis.del(STATE_KEY, QUEUE_KEY)
      end

      def self.resume_if_stalled!
        unless SiteSetting.inferred_concepts_enabled && DiscourseAi::Embeddings.enabled?
          return false
        end

        state = status
        return false if state.blank? || %w[queued running].exclude?(state["status"])
        return false unless stalled?(state)

        write_state(state.merge("updated_at" => Time.zone.now.iso8601))
        Jobs.enqueue(:seed_inferred_concepts, run_id: state["run_id"])
        true
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

      def self.stalled?(state)
        return false if Discourse.redis.exists?(MUTEX_KEY)

        timestamp = state["updated_at"] || state["started_at"] || state["queued_at"]
        return true if timestamp.blank?

        Time.zone.parse(timestamp.to_s) < WAVE_STALE_AFTER.ago
      rescue ArgumentError
        true
      end
      private_class_method :stalled?

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
        state = seed_wave!(limit: limit, enqueue_next: false)
        while state["status"] == "running"
          state = seed_wave!(run_id: state["run_id"], enqueue_next: false)
        end
        state
      end

      def seed_wave!(limit: nil, run_id: nil, enqueue_next: false)
        return { "status" => "skipped" } unless can_seed?

        agent_class = Classifier.resolve_agent(allow_new: true)&.class
        llm = agent_class ? Classifier.resolve_llm(allow_new: true, agent: agent_class.new) : nil
        if agent_class.nil? || llm.nil?
          now = Time.zone.now.iso8601
          Discourse.redis.del(QUEUE_KEY)
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

        result_state, should_enqueue_next, next_run_id =
          DistributedMutex.synchronize(MUTEX_KEY, validity: MUTEX_VALIDITY) do
            run_wave_locked(
              limit: limit,
              run_id: run_id,
              enqueue_next: enqueue_next,
              agent_class: agent_class,
              llm: llm,
            )
          end

        Jobs.enqueue(:seed_inferred_concepts, run_id: next_run_id) if should_enqueue_next

        result_state
      end

      private

      def can_seed?
        SiteSetting.inferred_concepts_enabled && DiscourseAi::Embeddings.enabled?
      end

      def run_wave_locked(limit:, run_id:, enqueue_next:, agent_class:, llm:)
        state = self.class.status

        return { "status" => "skipped" }, false, nil if stale_job_for_run?(state, run_id)

        if state.nil? || state["status"] != "running"
          state = initialize_run!(limit: limit, run_id: run_id || state&.dig("run_id"))
          return finalize_state(state), false, nil if state["total"].to_i == 0
        end

        begin
          LlmCreditAllocation.check_credits!(llm, FEATURE_NAME)
        rescue LlmCreditAllocation::CreditLimitExceeded => e
          Discourse.redis.del(QUEUE_KEY)
          flush_concept_embeddings
          curate_seeded_concepts if state["since_last_curate"].to_i > 0
          return finalize_state(state, error: e.message), false, nil
        end

        wave_ids = pop_wave_ids
        if wave_ids.empty?
          flush_concept_embeddings
          curate_seeded_concepts if state["since_last_curate"].to_i > 0
          return finalize_state(state), false, nil
        end

        process_popped_wave(
          state: state,
          wave_ids: wave_ids,
          enqueue_next: enqueue_next,
          agent_class: agent_class,
          llm: llm,
        )
      rescue StandardError => e
        Discourse.redis.del(QUEUE_KEY)
        write_terminal_error_state(state, e.message)
        raise
      end

      def stale_job_for_run?(state, run_id)
        return false if run_id.blank?
        return true if state.nil?
        return true if state["run_id"] != run_id

        %w[completed failed].include?(state["status"])
      end

      def initialize_run!(limit:, run_id:)
        effective_limit =
          (limit || SiteSetting.inferred_concepts_seed_topics_limit).to_i.clamp(1, MAX_SEED_TOPICS)
        topic_ids = select_seed_topics(limit: effective_limit)
        now = Time.zone.now.iso8601

        Discourse.redis.multi do |tx|
          tx.del(QUEUE_KEY)
          topic_ids.each_slice(1000) { |slice| tx.rpush(QUEUE_KEY, slice.map(&:to_s)) }
          tx.expire(QUEUE_KEY, QUEUE_TTL.to_i) if topic_ids.present?
        end

        write_progress(
          "status" => "running",
          "run_id" => run_id || SecureRandom.hex(8),
          "started_at" => now,
          "updated_at" => now,
          "processed" => 0,
          "total" => topic_ids.size,
          "initial_concepts" => InferredConcept.count,
          "since_last_curate" => 0,
        )
      end

      def pop_wave_ids
        popped =
          Discourse
            .redis
            .multi do |tx|
              tx.lrange(QUEUE_KEY, 0, @wave_size - 1)
              tx.ltrim(QUEUE_KEY, @wave_size, -1)
            end
            .first
        Array(popped).map(&:to_i)
      end

      def process_popped_wave(state:, wave_ids:, enqueue_next:, agent_class:, llm:)
        applier = Applier.new
        retriever = CandidateRetriever.new
        classifier = Classifier.new
        manager = Manager.new
        user = Discourse.system_user

        processed = state["processed"].to_i
        since_last_curate = state["since_last_curate"].to_i
        failed_error = nil

        work_items, skipped_count = prepare_wave(wave_ids, applier: applier, retriever: retriever)
        processed += skipped_count

        pool =
          if @concurrency > 1 && work_items.size > 1
            Scheduler::ThreadPool.new(min_threads: 0, max_threads: @concurrency, idle_time: 30)
          end

        wave_outcomes =
          begin
            classify_wave(
              work_items,
              pool: pool,
              classifier: classifier,
              agent_class: agent_class,
              llm: llm,
              user: user,
            )
          ensure
            if pool
              pool.shutdown
              pool.wait_for_termination(timeout: 30)
            end
          end

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
            begin
              manager.apply_classification_result(
                item[:topic],
                outcome[:result],
                candidates: item[:candidates],
                digest: item[:digest],
                allow_new: true,
                applier: applier,
              )
              since_last_curate += 1
            rescue StandardError => e
              Discourse.warn_exception(
                e,
                message: "Failed applying seeded inferred concepts for topic #{item[:topic].id}",
              )
            end
            processed += 1
          end
        end

        flush_concept_embeddings

        remaining = Discourse.redis.llen(QUEUE_KEY)
        next_state =
          state.merge(
            "processed" => processed,
            "since_last_curate" => since_last_curate,
            "updated_at" => Time.zone.now.iso8601,
          )

        if failed_error.present?
          Discourse.redis.del(QUEUE_KEY)
          curate_seeded_concepts if since_last_curate > 0
          return finalize_state(next_state, error: failed_error), false, nil
        end

        if remaining == 0
          curate_seeded_concepts if since_last_curate > 0
          return finalize_state(next_state), false, nil
        end

        Discourse.redis.expire(QUEUE_KEY, QUEUE_TTL.to_i)

        if @curate_every > 0 && since_last_curate >= @curate_every
          curate_seeded_concepts
          next_state["since_last_curate"] = 0
        end

        write_progress(next_state)
        [next_state, enqueue_next, next_state["run_id"]]
      end

      def finalize_state(state, error: nil)
        now = Time.zone.now.iso8601
        initial_concepts = state["initial_concepts"].to_i
        final_state = {
          "status" => error.present? ? "failed" : "completed",
          "run_id" => state["run_id"],
          "started_at" => state["started_at"] || now,
          "finished_at" => now,
          "updated_at" => now,
          "processed" => state["processed"].to_i,
          "total" => state["total"].to_i,
          "concepts_created" => [InferredConcept.count - initial_concepts, 0].max,
        }
        final_state["error"] = error if error.present?
        self.class.send(:write_state, final_state)
      end

      def write_terminal_error_state(state, error_message)
        base = state || {}
        now = Time.zone.now.iso8601
        self.class.send(
          :write_state,
          "status" => "failed",
          "run_id" => base["run_id"],
          "error" => error_message,
          "started_at" => base["started_at"] || now,
          "finished_at" => now,
          "updated_at" => now,
          "processed" => base["processed"].to_i,
          "total" => base["total"].to_i,
          "concepts_created" => [InferredConcept.count - base["initial_concepts"].to_i, 0].max,
        )
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
        rescue StandardError => e
          skipped_count += 1
          Discourse.warn_exception(
            e,
            message: "Failed preparing topic #{topic_id} for inferred concept seeding",
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
