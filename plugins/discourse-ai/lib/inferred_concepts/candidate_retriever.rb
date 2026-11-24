# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class CandidateRetriever
      DEFAULT_LIMIT = 30

      def self.serialize_candidates(concepts)
        Array(concepts).map do |concept|
          {
            id: concept.id,
            name: concept.name,
            description: concept.description.to_s,
            aliases: Array(concept.aliases),
          }
        end
      end

      def retrieve(content: nil, target: nil, limit: DEFAULT_LIMIT)
        non_retired = InferredConcept.where.not(status: :retired)
        return [] unless non_retired.exists?

        if DiscourseAi::Embeddings.enabled?
          vector = resolve_query_vector(content:, target:)
          if vector.present?
            results = vector_candidates(vector, non_retired:, limit:)
            return top_up_candidates(results, non_retired:, content:, limit:)
          end
        end

        lexical_candidates(non_retired, content:, limit:)
      end

      private

      def resolve_query_vector(content:, target:)
        if target.is_a?(Topic) || target.is_a?(Post)
          stored =
            DiscourseAi::Embeddings::Schema.for(target.class).find_by_target(target)&.embeddings
          return JSON.parse(stored) if stored.present?
        end

        return if content.blank?

        DiscourseAi::Embeddings::Vector.instance.vector_from(content, task: :query)
      rescue DiscourseAi::Inference::EmbeddingInferenceError,
             DiscourseAi::Embeddings::ProviderPausedError,
             DiscourseAi::Embeddings::Schema::MissingEmbeddingError,
             RuntimeError
        nil
      end

      def vector_candidates(vector, non_retired:, limit:)
        statuses = [InferredConcept.statuses[:active], InferredConcept.statuses[:candidate]]
        table = DiscourseAi::Embeddings::Schema::INFERRED_CONCEPTS_TABLE

        candidate_ids =
          DiscourseAi::Embeddings::Schema
            .for(InferredConcept)
            .asymmetric_similarity_search(vector, limit: limit, offset: 0) do |builder|
              builder.join(
                "inferred_concepts ON inferred_concepts.id = #{table}.inferred_concept_id",
              )
              builder.where("inferred_concepts.status IN (:statuses)", statuses: statuses)
            end
            .map(&:inferred_concept_id)

        return [] if candidate_ids.blank?

        by_id = non_retired.where(id: candidate_ids).index_by(&:id)
        candidate_ids.filter_map { |id| by_id[id] }
      rescue DiscourseAi::Embeddings::Schema::MissingEmbeddingError
        []
      end

      def top_up_candidates(results, non_retired:, content:, limit:)
        return results if results.size >= limit

        remaining = limit - results.size
        remaining_scope = non_retired.where.not(id: results.map(&:id))
        results + lexical_candidates(remaining_scope, content:, limit: remaining)
      end

      def lexical_candidates(scope, content:, limit:)
        return scope.order(status: :desc, id: :asc).limit(limit).to_a if content.blank?

        query_text = content.to_s.first(Applier::MAX_CONTENT_CHARS)
        score_sql =
          ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, query_text, query_text, query_text])
                (
                  CASE WHEN position(lower(inferred_concepts.name) IN lower(?)) > 0 THEN 10.0 ELSE 0.0 END +
                  CASE WHEN EXISTS (
                    SELECT 1
                    FROM unnest(inferred_concepts.aliases) AS alias
                    WHERE alias <> '' AND position(lower(alias) IN lower(?)) > 0
                  ) THEN 8.0 ELSE 0.0 END +
                  COALESCE((
                    SELECT COUNT(*)::float
                    FROM unnest(
                      tsvector_to_array(
                        to_tsvector(
                          'simple',
                          coalesce(inferred_concepts.name, '') || ' ' ||
                            coalesce(inferred_concepts.description, '') || ' ' ||
                            array_to_string(inferred_concepts.aliases, ' ')
                        )
                      )
                    ) AS concept_lexeme
                    WHERE concept_lexeme = ANY(tsvector_to_array(to_tsvector('simple', ?)))
                  ), 0.0)
                )
              SQL

        scope.order(Arel.sql("#{score_sql} DESC"), status: :desc, id: :asc).limit(limit).to_a
      end
    end
  end
end
