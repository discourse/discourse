# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Curator
      TIGHT_MAX_COSINE_DISTANCE = 0.30
      DEFAULT_MAX_COSINE_DISTANCE = 0.38
      DEFAULT_MAX_PASSES = 3
      NEIGHBOR_CANDIDATES_LIMIT = 100
      NEIGHBORS_PER_CONCEPT = 20
      MAX_CLUSTER_SIZE = 25
      MIN_CO_OCCURRENCE_SHARED_TOPICS = 3
      MIN_CO_OCCURRENCE_OVERLAP_RATIO = 0.5
      HIGH_CO_OCCURRENCE_SHARED_TOPICS = 10
      HIGH_CO_OCCURRENCE_OVERLAP_RATIO = 0.35
      MAX_RELATED_PAIRS = 40
      DEFAULT_STALE_CANDIDATE_AGE = 30.days
      MISSING_EMBEDDINGS_BATCH_LIMIT = 200
      MAX_DESCRIPTION_LENGTH = 1000
      FEATURE_NAME = "inferred_concepts_deduplicate"

      def curate!(
        max_cosine_distance: DEFAULT_MAX_COSINE_DISTANCE,
        stale_after: DEFAULT_STALE_CANDIDATE_AGE.ago,
        max_passes: DEFAULT_MAX_PASSES
      )
        unless DiscourseAi::Embeddings.enabled?
          return(
            {
              reconciled_retired: 0,
              clusters_processed: 0,
              merges_applied: 0,
              concepts_retired: 0,
              reparents_applied: 0,
              pruned_candidates: 0,
              promoted_candidates: 0,
              embeddings_enqueued: 0,
            }
          )
        end

        reconciled_retired = reconcile_retired_associations!
        dedup_stats = deduplicate_clusters!(max_cosine_distance:, max_passes:)
        prune_stats = prune_stale_candidates!(stale_after:)
        enqueued = enqueue_missing_embeddings

        dedup_stats.merge(prune_stats).merge(
          reconciled_retired: reconciled_retired,
          embeddings_enqueued: enqueued,
        )
      end

      def reconcile_retired_associations!
        retired_concepts =
          InferredConcept.retired.where(
            "EXISTS (SELECT 1 FROM inferred_concept_topics t WHERE t.inferred_concept_id = inferred_concepts.id) OR EXISTS (SELECT 1 FROM inferred_concept_posts p WHERE p.inferred_concept_id = inferred_concepts.id)",
          )

        merger = Merger.new
        reconciled = 0

        retired_concepts.find_each do |retired|
          canonical =
            InferredConcept.where.not(status: :retired).by_name_or_alias(retired.name).first
          next if canonical.nil?

          if merger.migrate_retired_associations!(canonical: canonical, retired: retired)
            reconciled += 1
          end
        end

        reconciled
      end

      def find_duplicate_clusters(
        max_cosine_distance: DEFAULT_MAX_COSINE_DISTANCE,
        max_cluster_size: MAX_CLUSTER_SIZE,
        include_co_occurrence: true
      )
        clusters, =
          cluster_candidates(
            max_cosine_distance: max_cosine_distance,
            max_cluster_size: max_cluster_size,
            include_co_occurrence: include_co_occurrence,
          )
        clusters
      end

      def deduplicate_clusters!(
        max_cosine_distance: DEFAULT_MAX_COSINE_DISTANCE,
        max_cluster_size: MAX_CLUSTER_SIZE,
        max_passes: DEFAULT_MAX_PASSES
      )
        stats = {
          clusters_processed: 0,
          merges_applied: 0,
          concepts_retired: 0,
          reparents_applied: 0,
        }
        return stats unless DiscourseAi::Embeddings.enabled?

        agent, llm = resolve_agent_and_llm
        return stats if agent.nil? || llm.nil?

        evaluated_pairs = Set.new
        pass_distances = build_pass_distances(max_cosine_distance:, max_passes:)
        credit_exceeded = false

        pass_distances.each_with_index do |distance, pass_index|
          clusters, vector_similarities =
            cluster_candidates(
              max_cosine_distance: distance,
              max_cluster_size: max_cluster_size,
              include_co_occurrence: true,
            )

          pending_clusters =
            clusters.select do |cluster|
              cluster
                .map(&:id)
                .combination(2)
                .any? do |a, b|
                  pair = a < b ? [a, b] : [b, a]
                  !evaluated_pairs.include?(pair)
                end
            end

          if pending_clusters.empty?
            break if distance >= max_cosine_distance
            next
          end

          pass_merges = 0
          updated_canonical_ids = Set.new

          pending_clusters.each do |cluster|
            begin
              LlmCreditAllocation.check_credits!(llm, FEATURE_NAME)
            rescue LlmCreditAllocation::CreditLimitExceeded
              credit_exceeded = true
              break
            end

            begin
              result =
                deduplicate_cluster(
                  cluster,
                  agent: agent,
                  llm: llm,
                  vector_similarities: vector_similarities,
                  updated_canonical_ids: updated_canonical_ids,
                )
              cluster
                .map(&:id)
                .combination(2) { |a, b| evaluated_pairs << (a < b ? [a, b] : [b, a]) }

              stats[:clusters_processed] += 1
              stats[:merges_applied] += result[:merges_applied]
              stats[:concepts_retired] += result[:concepts_retired]
              stats[:reparents_applied] += result[:reparents_applied]
              pass_merges += result[:merges_applied]
            rescue StandardError => e
              Discourse.warn_exception(
                e,
                message:
                  "Failed deduplicating inferred concept cluster #{cluster.map(&:id).inspect}",
              )
            end
          end

          break if credit_exceeded
          break if distance >= max_cosine_distance && pass_merges == 0

          if updated_canonical_ids.present? && pass_index < pass_distances.size - 1
            refresh_concept_embeddings(updated_canonical_ids)
          end
        end

        stats
      end

      def deduplicate_cluster(
        concepts,
        agent: nil,
        llm: nil,
        vector_similarities: {},
        updated_canonical_ids: nil
      )
        stats = { merges_applied: 0, concepts_retired: 0, reparents_applied: 0 }
        active_concepts = Array(concepts).reject(&:retired?)
        return stats if active_concepts.size < 2

        resolved_agent, resolved_llm = resolve_agent_and_llm
        agent ||= resolved_agent
        llm ||= resolved_llm
        return stats if agent.nil? || llm.nil?

        usage_counts = load_usage_counts(active_concepts.map(&:id))
        ordered_concepts = active_concepts.sort_by { |c| [-(usage_counts[c.id] || 0), c.id] }
        related_pairs =
          load_cluster_pair_signals(
            ordered_concepts,
            usage_counts: usage_counts,
            vector_similarities: vector_similarities,
          )

        payload = {
          concepts:
            ordered_concepts.map do |concept|
              {
                id: concept.id,
                name: concept.name,
                description: concept.description.to_s,
                aliases: Array(concept.aliases),
                status: concept.status,
                parent_id: concept.parent_id,
                usage_count: usage_counts[concept.id] || 0,
              }
            end,
          related_pairs: related_pairs,
        }

        context =
          DiscourseAi::Agents::BotContext.new(
            messages: [{ type: :user, content: payload.to_json }],
            user: Discourse.system_user,
            feature_name: FEATURE_NAME,
          )

        bot = DiscourseAi::Agents::Bot.as(Discourse.system_user, agent: agent, model: llm)
        structured_output = nil
        bot.reply(context) do |partial, _, type|
          structured_output = partial if type == :structured_output
        end

        return stats if structured_output.nil?

        plan = sanitize_plan(structured_output, active_concepts.map(&:id).to_set)
        apply_plan(plan, active_concepts, updated_canonical_ids: updated_canonical_ids)
      end

      def prune_stale_candidates!(stale_after: DEFAULT_STALE_CANDIDATE_AGE.ago)
        stale = InferredConcept.candidate.where("created_at < ?", stale_after).to_a
        return { pruned_candidates: 0, promoted_candidates: 0 } if stale.empty?

        usage_counts = load_usage_counts(stale.map(&:id))
        pruned = 0
        promoted = 0

        stale.each do |candidate|
          if (usage_counts[candidate.id] || 0) >= Manager::PROMOTION_THRESHOLD
            promoted_count =
              InferredConcept.where(
                id: candidate.id,
                status: InferredConcept.statuses[:candidate],
              ).update_all(status: InferredConcept.statuses[:active], updated_at: Time.zone.now)
            if promoted_count > 0
              candidate.status = :active
              promoted += 1
            end
          else
            candidate.destroy!
            pruned += 1
          end
        end

        { pruned_candidates: pruned, promoted_candidates: promoted }
      end

      def enqueue_missing_embeddings(limit: MISSING_EMBEDDINGS_BATCH_LIMIT)
        return 0 unless DiscourseAi::Embeddings.enabled?

        vector_def = EmbeddingDefinition.find_by(id: SiteSetting.ai_embeddings_selected_model)
        return 0 if vector_def.nil?

        table = DiscourseAi::Embeddings::Schema::INFERRED_CONCEPTS_TABLE
        missing_ids =
          InferredConcept
            .where.not(status: :retired)
            .where(
              "NOT EXISTS (SELECT 1 FROM #{table} e WHERE e.inferred_concept_id = inferred_concepts.id AND e.model_id = :model_id AND e.strategy_id = :strategy_id)",
              model_id: vector_def.id,
              strategy_id: vector_def.strategy_id,
            )
            .order(status: :desc, id: :asc)
            .limit(limit)
            .pluck(:id)

        missing_ids.each do |id|
          Jobs.enqueue(:generate_embeddings, target_type: "InferredConcept", target_id: id)
        end

        missing_ids.size
      end

      private

      def build_pass_distances(max_cosine_distance:, max_passes:)
        passes = [max_passes.to_i, 1].max
        if passes > 1 && max_cosine_distance > TIGHT_MAX_COSINE_DISTANCE
          [TIGHT_MAX_COSINE_DISTANCE] + Array.new(passes - 1, max_cosine_distance)
        else
          Array.new(passes, max_cosine_distance)
        end
      end

      def cluster_candidates(max_cosine_distance:, max_cluster_size:, include_co_occurrence:)
        return [], {} unless DiscourseAi::Embeddings.enabled?

        vector_def = EmbeddingDefinition.find_by(id: SiteSetting.ai_embeddings_selected_model)
        return [], {} if vector_def.nil?

        vector_edges = query_neighbor_edges(vector_def:, max_cosine_distance:)
        vector_similarities =
          vector_edges.each_with_object({}) do |(a, b, dist), acc|
            acc[[a, b]] = (1.0 - dist.to_f).clamp(0.0, 1.0).round(4)
          end

        co_occurrence_edges = include_co_occurrence ? query_co_occurrence_edges : []
        edges = vector_edges + co_occurrence_edges
        return [], vector_similarities if edges.empty?

        candidate_ids = edges.flat_map { |a, b, _| [a, b] }.uniq
        usage_counts = load_usage_counts(candidate_ids)

        component_ids = build_clusters(edges, max_cluster_size:, usage_counts:)
        return [], vector_similarities if component_ids.empty?

        concepts_by_id =
          InferredConcept
            .where.not(status: :retired)
            .where(id: component_ids.flatten)
            .index_by(&:id)

        clusters =
          component_ids.filter_map do |ids|
            cluster = ids.filter_map { |id| concepts_by_id[id] }
            cluster if cluster.size >= 2
          end

        [clusters, vector_similarities]
      end

      def query_co_occurrence_edges
        statuses = [InferredConcept.statuses[:active], InferredConcept.statuses[:candidate]]

        rows =
          DB.query(
            <<~SQL,
              WITH topic_counts AS (
                SELECT
                  ict.inferred_concept_id AS concept_id,
                  COUNT(DISTINCT ict.topic_id) AS topics_count
                FROM inferred_concept_topics ict
                INNER JOIN inferred_concepts c ON c.id = ict.inferred_concept_id
                WHERE c.status IN (:statuses)
                GROUP BY ict.inferred_concept_id
              )
              SELECT
                ict1.inferred_concept_id AS source_id,
                ict2.inferred_concept_id AS target_id,
                COUNT(DISTINCT ict1.topic_id)::float / LEAST(tc1.topics_count, tc2.topics_count) AS overlap_ratio
              FROM inferred_concept_topics ict1
              INNER JOIN inferred_concept_topics ict2
                ON ict2.topic_id = ict1.topic_id
                AND ict1.inferred_concept_id < ict2.inferred_concept_id
              INNER JOIN topic_counts tc1 ON tc1.concept_id = ict1.inferred_concept_id
              INNER JOIN topic_counts tc2 ON tc2.concept_id = ict2.inferred_concept_id
              GROUP BY
                ict1.inferred_concept_id,
                ict2.inferred_concept_id,
                tc1.topics_count,
                tc2.topics_count
              HAVING
                COUNT(DISTINCT ict1.topic_id) >= :min_shared
                AND (
                  COUNT(DISTINCT ict1.topic_id)::float / LEAST(tc1.topics_count, tc2.topics_count) >= :min_overlap
                  OR (
                    COUNT(DISTINCT ict1.topic_id) >= :high_shared
                    AND COUNT(DISTINCT ict1.topic_id)::float / LEAST(tc1.topics_count, tc2.topics_count) >= :high_overlap
                  )
                )
            SQL
            statuses: statuses,
            min_shared: MIN_CO_OCCURRENCE_SHARED_TOPICS,
            min_overlap: MIN_CO_OCCURRENCE_OVERLAP_RATIO,
            high_shared: HIGH_CO_OCCURRENCE_SHARED_TOPICS,
            high_overlap: HIGH_CO_OCCURRENCE_OVERLAP_RATIO,
          )

        rows.map do |row|
          [row.source_id, row.target_id, (1.0 - row.overlap_ratio.to_f).clamp(0.0, 1.0)]
        end
      end

      def load_cluster_pair_signals(concepts, usage_counts:, vector_similarities:)
        concept_ids = concepts.map(&:id)
        return [] if concept_ids.size < 2

        co_occurrence_rows = DB.query(<<~SQL, concept_ids: concept_ids)
              SELECT
                ict1.inferred_concept_id AS source_id,
                ict2.inferred_concept_id AS target_id,
                COUNT(DISTINCT ict1.topic_id) AS shared_topics
              FROM inferred_concept_topics ict1
              INNER JOIN inferred_concept_topics ict2
                ON ict2.topic_id = ict1.topic_id
                AND ict1.inferred_concept_id < ict2.inferred_concept_id
              WHERE ict1.inferred_concept_id IN (:concept_ids)
                AND ict2.inferred_concept_id IN (:concept_ids)
              GROUP BY ict1.inferred_concept_id, ict2.inferred_concept_id
            SQL

        shared_by_pair =
          co_occurrence_rows.each_with_object({}) do |row, acc|
            acc[[row.source_id, row.target_id]] = row.shared_topics.to_i
          end

        signals = []
        concept_ids.combination(2) do |id_a, id_b|
          pair = id_a < id_b ? [id_a, id_b] : [id_b, id_a]
          shared = shared_by_pair[pair] || 0
          similarity = vector_similarities[pair]
          next if shared == 0 && similarity.nil?

          min_usage = [usage_counts[pair[0]] || 0, usage_counts[pair[1]] || 0].min
          overlap_ratio = min_usage > 0 ? (shared.to_f / min_usage).clamp(0.0, 1.0).round(3) : 0.0

          entry = { concept_ids: pair, shared_topics: shared, overlap_ratio: overlap_ratio }
          entry[:similarity] = similarity if similarity.present?
          signals << entry
        end

        signals
          .sort_by do |entry|
            [-entry[:shared_topics], -entry[:overlap_ratio], -(entry[:similarity] || 0.0)]
          end
          .first(MAX_RELATED_PAIRS)
      end

      def refresh_concept_embeddings(concept_ids)
        return if concept_ids.blank? || !DiscourseAi::Embeddings.enabled?

        DiscourseAi::Embeddings::Vector.instance.gen_bulk_reprensentations(
          InferredConcept.where.not(status: :retired).where(id: concept_ids.to_a),
        )
      rescue StandardError => e
        Discourse.warn_exception(
          e,
          message: "Failed refreshing embeddings for merged inferred concepts",
        )
      end

      def query_neighbor_edges(vector_def:, max_cosine_distance:)
        dimensions = vector_def.dimensions.to_i
        table = DiscourseAi::Embeddings::Schema::INFERRED_CONCEPTS_TABLE
        statuses = [InferredConcept.statuses[:active], InferredConcept.statuses[:candidate]]

        rows =
          ActiveRecord::Base.transaction do
            DB.exec("SET LOCAL hnsw.iterative_scan = relaxed_order;")

            DB.query(
              <<~SQL,
                WITH embedded AS (
                  SELECT e.inferred_concept_id AS concept_id, e.embeddings
                  FROM #{table} e
                  INNER JOIN inferred_concepts c ON c.id = e.inferred_concept_id
                  WHERE e.model_id = :model_id
                    AND e.strategy_id = :strategy_id
                    AND c.status IN (:statuses)
                )
                SELECT
                  a.concept_id AS source_id,
                  neighbors.concept_id AS target_id,
                  neighbors.cosine_distance
                FROM embedded a
                CROSS JOIN LATERAL (
                  SELECT
                    candidates.concept_id,
                    (a.embeddings::halfvec(#{dimensions}) <=> candidates.embeddings::halfvec(#{dimensions})) AS cosine_distance
                  FROM (
                    SELECT b.concept_id, b.embeddings
                    FROM embedded b
                    WHERE b.concept_id <> a.concept_id
                    ORDER BY binary_quantize(b.embeddings)::bit(#{dimensions}) <~> binary_quantize(a.embeddings)::bit(#{dimensions})
                    LIMIT :neighbor_candidates
                  ) candidates
                  WHERE (a.embeddings::halfvec(#{dimensions}) <=> candidates.embeddings::halfvec(#{dimensions})) <= :max_cosine_distance
                  ORDER BY cosine_distance ASC
                  LIMIT :neighbors_per_concept
                ) neighbors
              SQL
              model_id: vector_def.id,
              strategy_id: vector_def.strategy_id,
              statuses: statuses,
              neighbor_candidates: NEIGHBOR_CANDIDATES_LIMIT,
              neighbors_per_concept: NEIGHBORS_PER_CONCEPT,
              max_cosine_distance: max_cosine_distance.to_f,
            )
          end

        undirected = {}
        rows.each do |row|
          pair =
            (
              if row.source_id < row.target_id
                [row.source_id, row.target_id]
              else
                [row.target_id, row.source_id]
              end
            )
          dist = row.cosine_distance.to_f
          undirected[pair] = dist if !undirected.key?(pair) || dist < undirected[pair]
        end

        undirected.map { |(a, b), dist| [a, b, dist] }.sort_by(&:last)
      rescue PG::Error => e
        Rails.logger.error(
          "Error #{e} querying inferred concept clusters for #{vector_def.display_name}",
        )
        []
      end

      def build_clusters(edges, max_cluster_size:, usage_counts: {})
        adjacency = Hash.new { |h, k| h[k] = {} }

        edges.each do |a, b, dist|
          d = dist.to_f
          adjacency[a][b] = d if !adjacency[a].key?(b) || d < adjacency[a][b]
          adjacency[b][a] = d if !adjacency[b].key?(a) || d < adjacency[b][a]
        end

        return [] if adjacency.empty?

        assigned = Set.new
        clusters = []
        seeds =
          adjacency.keys.sort_by { |id| [-(usage_counts[id] || 0), adjacency[id].values.min, id] }

        seeds.each do |seed|
          next if assigned.include?(seed)

          neighbors =
            adjacency[seed]
              .keys
              .reject { |nid| assigned.include?(nid) }
              .sort_by { |nid| [adjacency[seed][nid], -(usage_counts[nid] || 0), nid] }
          next if neighbors.empty?

          cluster = [seed] + neighbors.first([max_cluster_size - 1, 0].max)
          cluster.each { |id| assigned << id }
          clusters << cluster if cluster.size >= 2
        end

        clusters
      end

      def resolve_agent_and_llm
        agent_id = SiteSetting.inferred_concepts_deduplicate_agent.to_i
        agent = AiAgent.all_agents(enabled_only: false).find { |a| a.id == agent_id }&.new
        return nil, nil if agent.nil?

        llm =
          LlmModel.find_by(
            id: agent.class.default_llm_id.presence || SiteSetting.ai_default_llm_model,
          )
        return nil, nil if llm.nil?

        [agent, llm]
      end

      def load_usage_counts(concept_ids)
        return {} if concept_ids.blank?

        topic_counts =
          InferredConceptTopic
            .where(inferred_concept_id: concept_ids)
            .group(:inferred_concept_id)
            .count
        post_counts =
          InferredConceptPost
            .where(inferred_concept_id: concept_ids)
            .group(:inferred_concept_id)
            .count

        concept_ids.index_with { |id| (topic_counts[id] || 0) + (post_counts[id] || 0) }
      end

      def sanitize_plan(structured_output, valid_ids)
        absorbed_ids = Set.new
        canonical_ids = Set.new
        merges = []

        Array(structured_output.read_buffered_property(:merges)).each do |item|
          next unless item.is_a?(Hash)

          entry = item.with_indifferent_access
          canonical_id = entry[:canonical_id]&.to_i
          next if canonical_id.nil? || !valid_ids.include?(canonical_id)
          next if absorbed_ids.include?(canonical_id) || canonical_ids.include?(canonical_id)

          merge_ids =
            Array(entry[:merge_ids])
              .filter_map { |id| id&.to_i }
              .uniq
              .select do |id|
                id != canonical_id && valid_ids.include?(id) && !canonical_ids.include?(id) &&
                  !absorbed_ids.include?(id)
              end
          next if merge_ids.empty?

          canonical_ids << canonical_id
          absorbed_ids.merge(merge_ids)
          merges << {
            canonical_id: canonical_id,
            merge_ids: merge_ids,
            description: normalize_utf8(entry[:description]).strip.first(MAX_DESCRIPTION_LENGTH),
          }
        end

        reparents = []
        Array(structured_output.read_buffered_property(:reparents)).each do |item|
          next unless item.is_a?(Hash)

          entry = item.with_indifferent_access
          concept_id = entry[:concept_id]&.to_i
          parent_id = entry[:parent_concept_id]&.to_i
          next if concept_id.nil? || parent_id.nil? || concept_id == parent_id
          next if valid_ids.exclude?(concept_id) || valid_ids.exclude?(parent_id)
          next if absorbed_ids.include?(concept_id) || absorbed_ids.include?(parent_id)

          reparents << { concept_id: concept_id, parent_concept_id: parent_id }
        end

        { merges: merges, reparents: reparents }
      end

      def apply_plan(plan, active_concepts, updated_canonical_ids: nil)
        stats = { merges_applied: 0, concepts_retired: 0, reparents_applied: 0 }
        by_id = active_concepts.index_by(&:id)
        merger = Merger.new

        plan[:merges].each do |entry|
          canonical = by_id[entry[:canonical_id]]
          duplicates = entry[:merge_ids].filter_map { |id| by_id[id] }
          next if canonical.nil? || duplicates.empty?

          merger.merge!(
            canonical: canonical,
            duplicates: duplicates,
            description: entry[:description],
          )
          retired_count = InferredConcept.retired.where(id: duplicates.map(&:id)).count
          if retired_count > 0
            updated_canonical_ids&.add(canonical.id)
            stats[:merges_applied] += 1
            stats[:concepts_retired] += retired_count
          end
        end

        if plan[:reparents].present?
          reloaded = InferredConcept.where(id: by_id.keys).index_by(&:id)
          plan[:reparents].each do |entry|
            concept = reloaded[entry[:concept_id]]
            parent = reloaded[entry[:parent_concept_id]]
            stats[:reparents_applied] += 1 if merger.reparent!(concept: concept, parent: parent)
          end
        end

        stats
      end

      def normalize_utf8(value)
        str = value.to_s
        return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?

        str.dup.force_encoding(Encoding::UTF_8).scrub("")
      end
    end
  end
end
