# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Seeder
      STATE_KEY = "discourse_ai:inferred_concepts:seed_state"
      MUTEX_KEY = "discourse_ai_seed_inferred_concepts"
      MUTEX_VALIDITY = 30.minutes
      STALE_AFTER = 1.hour
      TERMINAL_STATE_TTL = 24.hours
      RECENT_WINDOW = 2.years
      MIN_WORD_COUNT = 50
      EMBED_FLUSH_INTERVAL = 15
      PROGRESS_UPDATE_INTERVAL = 10

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

        effective_limit =
          (limit || SiteSetting.inferred_concepts_seed_topics_limit).to_i.clamp(1, 2000)

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

          manager = Manager.new
          processed = 0
          failed_error = nil

          topic_ids.each do |topic_id|
            topic = Topic.find_by(id: topic_id)
            next if topic.blank?

            manager.generate_concepts_from_topic(topic)
            processed += 1

            flush_concept_embeddings if (processed % EMBED_FLUSH_INTERVAL).zero?

            if (processed % PROGRESS_UPDATE_INTERVAL).zero?
              write_progress(
                "status" => "running",
                "started_at" => started_at,
                "updated_at" => Time.zone.now.iso8601,
                "processed" => processed,
                "total" => topic_ids.size,
              )
            end
          rescue LlmCreditAllocation::CreditLimitExceeded => e
            failed_error = e.message
            break
          rescue StandardError => e
            processed += 1
            Discourse.warn_exception(
              e,
              message: "Failed seeding inferred concepts for topic #{topic_id}",
            )
          end

          flush_concept_embeddings
          curate_seeded_concepts

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
