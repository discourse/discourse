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
      def match_existing_concepts(topic)
        return [] if topic.blank?

        content = topic_content_for_analysis(topic)
        return [] if content.blank?

        digest = content_digest(content)
        if InferredConceptTopic.where(topic_id: topic.id, digest: digest).exists?
          return topic.inferred_concepts.to_a
        end

        candidates = CandidateRetriever.new.retrieve(content: content, target: topic)
        return [] if candidates.empty?

        result = Classifier.new.classify(content, candidates: candidates, allow_new: false)
        match_entries = build_match_entries(result[:matches], candidates)

        apply_matches_to_topic(topic, match_entries, digest: digest)
      end

      # Match a post with existing concepts
      def match_existing_concepts_for_post(post)
        return [] if post.blank?

        content = post_content_for_analysis(post)
        return [] if content.blank?

        digest = content_digest(content)
        if InferredConceptPost.where(post_id: post.id, digest: digest).exists?
          return post.inferred_concepts.to_a
        end

        candidates = CandidateRetriever.new.retrieve(content: content, target: post)
        return [] if candidates.empty?

        result = Classifier.new.classify(content, candidates: candidates, allow_new: false)
        match_entries = build_match_entries(result[:matches], candidates)

        apply_matches_to_post(post, match_entries, digest: digest)
      end

      # Use ConceptMatcher agent to match content against provided concepts
      def match_concepts_to_content(content, concept_list)
        return [] if content.blank? || concept_list.blank?

        candidates = resolve_candidates(concept_list)
        return [] if candidates.empty?

        result = Classifier.new.classify(content, candidates: candidates, allow_new: false)
        by_id = candidates.index_by(&:id)
        result[:matches].filter_map { |match| by_id[match[:concept_id]]&.name }
      end

      private

      def apply_matches(target, join_model:, table_name:, fk_column:, match_entries:, digest:)
        return [] if target.blank?

        entries = Array(match_entries).uniq { |entry| entry[:concept].id }

        ActiveRecord::Base.transaction do
          if digest.present? && entries.present?
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
