# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Applier
      MAX_CONTENT_CHARS = 12_000
      CandidateStub = Struct.new(:id, :name, :description, :aliases)

      # Associates the provided concepts with a topic
      # topic: a Topic instance
      # concepts: an array of InferredConcept instances
      def apply_to_topic(topic, concepts)
        return if topic.blank? || concepts.blank?

        entries = Array(concepts).map { |concept| { concept:, relevance: 1.0, primary: false } }
        apply_matches_to_topic(topic, entries)
      end

      # Associates the provided concepts with a post
      # post: a Post instance
      # concepts: an array of InferredConcept instances
      def apply_to_post(post, concepts)
        return if post.blank? || concepts.blank?

        entries = Array(concepts).map { |concept| { concept:, relevance: 1.0, primary: false } }
        apply_matches_to_post(post, entries)
      end

      def apply_matches_to_topic(topic, match_entries, digest: "")
        apply_matches(
          topic,
          join_model: InferredConceptTopic,
          table_name: "inferred_concept_topics",
          fk_column: "topic_id",
          match_entries: match_entries,
          digest: digest,
        )
      end

      def apply_matches_to_post(post, match_entries, digest: "")
        apply_matches(
          post,
          join_model: InferredConceptPost,
          table_name: "inferred_concept_posts",
          fk_column: "post_id",
          match_entries: match_entries,
          digest: digest,
        )
      end

      def content_digest(content)
        OpenSSL::Digest::SHA1.hexdigest(content.to_s)
      end

      # Extracts content from a topic for concept analysis
      # Returns a string with the topic title, metadata, and first few regular posts
      def topic_content_for_analysis(topic)
        return "" if topic.blank?

        lines = ["Title: #{topic.title}"]
        lines << "Category: #{topic.category.name}" if topic.category&.name.present?
        if SiteSetting.tagging_enabled && topic.tags.present?
          lines << "Tags: #{topic.tags.pluck(:name).join(", ")}"
        end

        posts =
          Post
            .where(topic_id: topic.id, post_type: Post.types[:regular])
            .includes(:user)
            .order(:post_number)
            .limit(10)

        posts_text =
          posts
            .map { |post| "#{post.post_number}) #{post.user&.username || "system"}: #{post.raw}" }
            .join("\n\n")

        content = "#{lines.join("\n")}\n\n#{posts_text}"
        content.first(MAX_CONTENT_CHARS)
      end

      # Extracts content from a post for concept analysis
      # Returns a string with the post content
      def post_content_for_analysis(post)
        return "" if post.blank?

        topic_title = post.topic&.title || ""

        content =
          "Topic: #{topic_title}\n\nPost by #{post.user&.username || "system"}:\n#{post.raw}"
        content.first(MAX_CONTENT_CHARS)
      end

      # Match a topic with existing concepts
      def match_existing_concepts(
        topic,
        active_only: false,
        require_stored_embedding: false,
        raise_on_error: false
      )
        return [] if ineligible_target?(topic) || !DiscourseAi::Embeddings.enabled?

        content = topic_content_for_analysis(topic)
        return [] if content.blank?

        digest = content_digest(content)
        if InferredConceptTopic.where(topic_id: topic.id, digest: digest).exists?
          return topic.inferred_concepts.to_a
        end

        candidates =
          CandidateRetriever.new.retrieve(
            content: content,
            target: topic,
            limit: matcher_candidate_limit,
            active_only: active_only,
            require_stored_embedding: require_stored_embedding,
          )
        return [] if candidates.empty?

        matches = classify_for_matching(content, candidates:, raise_on_error:)
        match_entries = build_match_entries(matches, candidates)

        apply_matches_to_topic(topic, match_entries, digest: digest)
      rescue CandidateRetriever::EmbeddingsUnavailableError,
             DiscourseAi::Embeddings::ProviderPausedError,
             DiscourseAi::Inference::EmbeddingInferenceError,
             DiscourseAi::Decisions::Error,
             LlmCreditAllocation::CreditLimitExceeded
        raise if raise_on_error

        []
      end

      # Match a post with existing concepts
      def match_existing_concepts_for_post(
        post,
        active_only: false,
        require_stored_embedding: false,
        raise_on_error: false
      )
        return [] if ineligible_target?(post) || !DiscourseAi::Embeddings.enabled?

        content = post_content_for_analysis(post)
        return [] if content.blank?

        digest = content_digest(content)
        if InferredConceptPost.where(post_id: post.id, digest: digest).exists?
          return post.inferred_concepts.to_a
        end

        candidates =
          CandidateRetriever.new.retrieve(
            content: content,
            target: post,
            limit: matcher_candidate_limit,
            active_only: active_only,
            require_stored_embedding: require_stored_embedding,
          )
        return [] if candidates.empty?

        matches = classify_for_matching(content, candidates:, raise_on_error:)
        match_entries = build_match_entries(matches, candidates)

        apply_matches_to_post(post, match_entries, digest: digest)
      rescue CandidateRetriever::EmbeddingsUnavailableError,
             DiscourseAi::Embeddings::ProviderPausedError,
             DiscourseAi::Inference::EmbeddingInferenceError,
             DiscourseAi::Decisions::Error,
             LlmCreditAllocation::CreditLimitExceeded
        raise if raise_on_error

        []
      end

      # Use ConceptMatcher or configured decision model to match content against provided concepts
      def match_concepts_to_content(content, concept_list)
        return [] if content.blank? || concept_list.blank?

        candidates = resolve_candidates(concept_list)
        return [] if candidates.empty?

        matches = classify_for_matching(content, candidates:, raise_on_error: false)
        by_id = candidates.index_by(&:id)
        matches.filter_map { |match| by_id[match[:concept_id]]&.name }
      end

      private

      def matcher_candidate_limit
        if DecisionMatcher.available?
          DecisionMatcher::MAX_CANDIDATES
        else
          CandidateRetriever::DEFAULT_LIMIT
        end
      end

      def classify_for_matching(content, candidates:, raise_on_error:)
        if DecisionMatcher.available?
          result = DecisionMatcher.new.match(content, candidates: candidates)
          if result[:all_refused]
            if raise_on_error
              raise DiscourseAi::Decisions::RequestFailed,
                    "Decision model refused all concept questions"
            end
            return []
          end
          result[:matches]
        else
          Classifier.new.classify(content, candidates: candidates, allow_new: false)[:matches]
        end
      end

      def ineligible_target?(target)
        return true if target.blank?

        topic = target.is_a?(Topic) ? target : target.topic
        target.deleted_at.present? || topic.nil? || topic.deleted_at.present? ||
          topic.private_message?
      end

      def apply_matches(target, join_model:, table_name:, fk_column:, match_entries:, digest:)
        return [] if target.blank? || match_entries.blank?

        entries = resolve_surviving_entries(match_entries)
        return [] if entries.empty?

        ActiveRecord::Base.transaction do
          if digest.present?
            keep_ids = entries.map { |entry| entry[:concept].id }
            join_model
              .where(fk_column => target.id)
              .where.not(inferred_concept_id: keep_ids)
              .delete_all
          end

          now = Time.zone.now
          entries.each do |entry|
            DB.exec(
              <<~SQL,
                INSERT INTO #{table_name} (#{fk_column}, inferred_concept_id, relevance, "primary", digest, created_at, updated_at)
                VALUES (:target_id, :concept_id, :relevance, :primary, :digest, :now, :now)
                ON CONFLICT (#{fk_column}, inferred_concept_id)
                DO UPDATE SET
                  relevance = EXCLUDED.relevance,
                  "primary" = EXCLUDED."primary",
                  digest = EXCLUDED.digest,
                  updated_at = EXCLUDED.updated_at
              SQL
              target_id: target.id,
              concept_id: entry[:concept].id,
              relevance: entry[:relevance].to_f.clamp(0.0, 1.0),
              primary: entry[:primary] == true,
              digest: digest.to_s,
              now: now,
            )
          end
        end

        target.inferred_concepts.reset
        entries.map { |entry| entry[:concept] }
      end

      def resolve_surviving_entries(match_entries)
        consolidated = consolidate_entries(match_entries)
        return [] if consolidated.empty?

        reloaded_by_id =
          InferredConcept.where(id: consolidated.map { |entry| entry[:concept].id }).index_by(&:id)

        rebuilt =
          consolidated.filter_map do |entry|
            reloaded = reloaded_by_id[entry[:concept].id]
            if reloaded.present? && !reloaded.retired?
              entry.merge(concept: reloaded)
            else
              lookup_name = reloaded&.name || entry[:concept].name
              replacement =
                InferredConcept.where.not(status: :retired).by_name_or_alias(lookup_name).first
              replacement ? entry.merge(concept: replacement) : nil
            end
          end

        consolidate_entries(rebuilt)
      end

      def consolidate_entries(entries)
        by_id = {}

        Array(entries).each do |entry|
          concept = entry[:concept]
          next if concept&.id.nil?

          existing = by_id[concept.id]
          relevance = entry[:relevance].to_f
          primary = entry[:primary] == true

          if existing.nil?
            by_id[concept.id] = { concept: concept, relevance: relevance, primary: primary }
          else
            existing[:relevance] = [existing[:relevance], relevance].max
            existing[:primary] ||= primary
          end
        end

        by_id.values
      end

      def build_match_entries(matches, candidates)
        by_id = candidates.index_by(&:id)
        matches.filter_map do |match|
          concept = by_id[match[:concept_id]]
          next if concept.nil?

          { concept:, relevance: match[:relevance], primary: match[:primary] }
        end
      end

      def resolve_candidates(concept_list)
        return concept_list.reject(&:retired?) if concept_list.first.is_a?(InferredConcept)

        names = concept_list.map(&:to_s)
        by_name = InferredConcept.where(name: names).index_by(&:name)

        names.each_with_index.filter_map do |name, index|
          existing = by_name[name]
          if existing
            next if existing.retired?
            existing
          else
            CandidateStub.new(-(index + 1), name, "", [])
          end
        end
      end
    end
  end
end
