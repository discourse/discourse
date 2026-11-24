# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Merger
      MAX_DESCRIPTION_LENGTH = 1000

      def merge!(canonical:, duplicates:, description: nil)
        candidates = Array(duplicates).compact.uniq(&:id)
        return canonical if canonical.nil? || canonical.retired?

        candidates.reject! { |dup| dup.id == canonical.id || dup.retired? }
        return canonical if candidates.empty?

        retired_duplicates = []

        ActiveRecord::Base.transaction do
          locked_ids = ([canonical.id] + candidates.map(&:id)).uniq
          locked_by_id = InferredConcept.where(id: locked_ids).order(:id).lock.load.index_by(&:id)

          canonical = locked_by_id[canonical.id]
          active_duplicates =
            candidates.filter_map { |dup| locked_by_id[dup.id] }.reject(&:retired?)
          return canonical if canonical.nil? || canonical.retired? || active_duplicates.empty?

          dup_ids = active_duplicates.map(&:id)
          now = Time.zone.now

          migrate_associations!(
            join_model: InferredConceptTopic,
            table_name: "inferred_concept_topics",
            fk_column: "topic_id",
            canonical_id: canonical.id,
            duplicate_ids: dup_ids,
            now: now,
          )
          migrate_associations!(
            join_model: InferredConceptPost,
            table_name: "inferred_concept_posts",
            fk_column: "post_id",
            canonical_id: canonical.id,
            duplicate_ids: dup_ids,
            now: now,
          )

          reconcile_hierarchy!(canonical:, dup_ids:, locked_by_id:)
          consolidate_canonical!(canonical:, active_duplicates:, description:)
          active_duplicates.each do |dup|
            dup.update!(status: :retired, parent_id: nil, aliases: [])
          end

          retired_duplicates = active_duplicates
        end

        if retired_duplicates.present?
          retired_duplicates.each do |dup|
            DiscourseAi::Embeddings::Schema.delete_embeddings_for(dup)
          end
          if DiscourseAi::Embeddings.enabled?
            Jobs.enqueue(
              :generate_embeddings,
              target_type: "InferredConcept",
              target_id: canonical.id,
            )
          end
        end

        canonical
      end

      def reparent!(concept:, parent:)
        return false if concept.nil? || parent.nil? || concept.retired? || parent.retired?
        return false if concept.id == parent.id
        return false if ancestor_ids_of(parent).include?(concept.id)

        concept.update!(parent_id: parent.id)
        true
      end

      private

      def migrate_associations!(
        join_model:,
        table_name:,
        fk_column:,
        canonical_id:,
        duplicate_ids:,
        now:
      )
        DB.exec(<<~SQL, canonical_id: canonical_id, duplicate_ids: duplicate_ids, now: now)
            INSERT INTO #{table_name} (#{fk_column}, inferred_concept_id, relevance, "primary", digest, created_at, updated_at)
            SELECT
              #{fk_column},
              :canonical_id,
              MAX(relevance),
              BOOL_OR("primary"),
              MAX(digest),
              MIN(created_at),
              :now
            FROM #{table_name}
            WHERE inferred_concept_id IN (:duplicate_ids)
            GROUP BY #{fk_column}
            ON CONFLICT (#{fk_column}, inferred_concept_id)
            DO UPDATE SET
              relevance = GREATEST(#{table_name}.relevance, EXCLUDED.relevance),
              "primary" = #{table_name}."primary" OR EXCLUDED."primary",
              digest = COALESCE(NULLIF(#{table_name}.digest, ''), EXCLUDED.digest),
              updated_at = EXCLUDED.updated_at
          SQL

        join_model.where(inferred_concept_id: duplicate_ids).delete_all
      end

      def reconcile_hierarchy!(canonical:, dup_ids:, locked_by_id:)
        if dup_ids.include?(canonical.parent_id)
          canonical.parent_id =
            nearest_surviving_ancestor(
              canonical.parent_id,
              canonical_id: canonical.id,
              dup_ids: dup_ids,
              locked_by_id: locked_by_id,
            )
        end

        canonical_ancestors = ancestor_ids_of(canonical)
        affected_children =
          InferredConcept.where(parent_id: dup_ids).where.not(id: [canonical.id, *dup_ids])

        if canonical_ancestors.present?
          affected_children.where(id: canonical_ancestors.to_a).update_all(parent_id: nil)
          affected_children
            .where.not(id: canonical_ancestors.to_a)
            .update_all(parent_id: canonical.id)
        else
          affected_children.update_all(parent_id: canonical.id)
        end
      end

      def nearest_surviving_ancestor(start_id, canonical_id:, dup_ids:, locked_by_id:)
        visited = Set[canonical_id]
        current_id = start_id

        while current_id.present?
          return nil if visited.include?(current_id)

          visited << current_id
          return current_id if dup_ids.exclude?(current_id)

          current_id =
            if locked_by_id.key?(current_id)
              locked_by_id[current_id].parent_id
            else
              InferredConcept.where(id: current_id).pick(:parent_id)
            end
        end

        nil
      end

      def ancestor_ids_of(concept)
        ancestors = Set[concept.id]
        current_id = concept.parent_id

        while current_id.present? && !ancestors.include?(current_id)
          ancestors << current_id
          current_id = InferredConcept.where(id: current_id).pick(:parent_id)
        end

        ancestors
      end

      def consolidate_canonical!(canonical:, active_duplicates:, description:)
        canonical.aliases =
          Array(canonical.aliases) + active_duplicates.flat_map { |dup| [dup.name, *dup.aliases] }

        if description.present?
          canonical.description = normalize_utf8(description).strip.first(MAX_DESCRIPTION_LENGTH)
        elsif canonical.description.blank?
          fallback_description =
            active_duplicates.filter_map { |dup| dup.description.presence }.first
          canonical.description = fallback_description if fallback_description.present?
        end

        if canonical.candidate?
          usage_count =
            InferredConceptTopic.where(inferred_concept_id: canonical.id).count +
              InferredConceptPost.where(inferred_concept_id: canonical.id).count

          if active_duplicates.any?(&:active?) || usage_count >= Manager::PROMOTION_THRESHOLD
            canonical.status = :active
          end
        end

        canonical.save!
      end

      def normalize_utf8(value)
        str = value.to_s
        return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?

        str.dup.force_encoding(Encoding::UTF_8).scrub("")
      end
    end
  end
end
