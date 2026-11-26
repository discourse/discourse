# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class CandidateRetriever
      DEFAULT_LIMIT = 30
      EmbeddingsUnavailableError = Class.new(StandardError)

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

      def retrieve(
        content: nil,
        target: nil,
        limit: DEFAULT_LIMIT,
        active_only: false,
        require_stored_embedding: false
      )
        unless DiscourseAi::Embeddings.enabled?
          raise EmbeddingsUnavailableError, "AI embeddings must be enabled"
        end

        return [] if ineligible_target?(target)

        concept_scope =
          active_only ? InferredConcept.active : InferredConcept.where.not(status: :retired)
        return [] unless concept_scope.exists?

        vector = resolve_query_vector(content:, target:, require_stored_embedding:)
        return [] if vector.blank?

        results = vector_candidates(vector, concept_scope:, active_only:, limit:)
        top_up_unembedded(results, concept_scope:, limit:)
      end

      private

      def ineligible_target?(target)
        return false unless target.is_a?(Topic) || target.is_a?(Post)

        topic = target.is_a?(Topic) ? target : target.topic
        target.deleted_at.present? || topic.nil? || topic.deleted_at.present? ||
          (topic.private_message? && !SiteSetting.ai_embeddings_generate_for_pms)
      end

      def resolve_query_vector(content:, target:, require_stored_embedding: false)
        if target.is_a?(Topic) || target.is_a?(Post)
          stored =
            DiscourseAi::Embeddings::Schema.for(target.class).find_by_target(target)&.embeddings
          return JSON.parse(stored) if stored.present?
        end

        return if require_stored_embedding || content.blank?

        DiscourseAi::Embeddings::Vector.instance.vector_from(content, task: :query)
      end

      def vector_candidates(vector, concept_scope:, active_only:, limit:)
        statuses =
          if active_only
            [InferredConcept.statuses[:active]]
          else
            [InferredConcept.statuses[:active], InferredConcept.statuses[:candidate]]
          end
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

        by_id = concept_scope.where(id: candidate_ids).index_by(&:id)
        candidate_ids.filter_map { |id| by_id[id] }
      rescue DiscourseAi::Embeddings::Schema::MissingEmbeddingError
        []
      end

      def top_up_unembedded(results, concept_scope:, limit:)
        return results if results.size >= limit

        remaining = limit - results.size
        model_id = SiteSetting.ai_embeddings_selected_model.to_i
        table = DiscourseAi::Embeddings::Schema::INFERRED_CONCEPTS_TABLE

        unembedded =
          concept_scope
            .where.not(id: results.map(&:id))
            .where(
              "NOT EXISTS (SELECT 1 FROM #{table} e WHERE e.inferred_concept_id = inferred_concepts.id AND e.model_id = :model_id)",
              model_id: model_id,
            )
            .order(status: :desc, id: :asc)
            .limit(remaining)
            .to_a

        results + unembedded
      end
    end
  end
end
