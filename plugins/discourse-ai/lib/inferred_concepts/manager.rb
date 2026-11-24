# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Manager
      PROMOTION_THRESHOLD = 2

      # Get a list of existing non-retired concept names
      # @param limit [Integer, nil] Optional maximum number of concepts to return
      # @return [Array<String>] Array of concept names
      def list_concepts(limit: nil)
        query = InferredConcept.where.not(status: :retired).order("name ASC")

        # Apply limit if provided
        query = query.limit(limit) if limit.present?

        query.pluck(:name)
      end

      # Deduplicate concepts in batches by letter
      # This method will:
      # 1. Group concepts by first letter
      # 2. Process each letter group separately through the deduplicator
      # 3. Do a final pass with all deduplicated concepts
      # @return [Hash] Statistics about the deduplication process
      def deduplicate_concepts_by_letter(per_letter_batch: 50, full_pass_batch: 150)
        # Get all concepts
        all_concepts = list_concepts
        return if all_concepts.empty?

        letter_groups = Hash.new { |h, k| h[k] = [] }

        # Group concepts by first letter
        all_concepts.each do |concept|
          first_char = concept[0]&.upcase

          if first_char && first_char.match?(/[A-Z]/)
            letter_groups[first_char] << concept
          else
            # Non-alphabetic or empty concepts go in a special group
            letter_groups["#"] << concept
          end
        end

        # Process each letter group
        letter_deduplicated_concepts = []
        finder = DiscourseAi::InferredConcepts::Finder.new

        letter_groups.each do |letter, concepts|
          next if concepts.empty?

          batches = concepts.each_slice(per_letter_batch).to_a

          batches.each do |batch|
            result = finder.deduplicate_concepts(batch)
            letter_deduplicated_concepts.concat(result)
          end
        end

        # Final pass with all deduplicated concepts
        if letter_deduplicated_concepts.present?
          final_result = []

          batches = letter_deduplicated_concepts.each_slice(full_pass_batch).to_a
          batches.each do |batch|
            dedups = finder.deduplicate_concepts(batch)
            final_result.concat(dedups)
          end

          # Remove duplicates
          final_result.uniq!

          # Apply deduplication only to concepts included in the deduplication pass
          removed_names = all_concepts - final_result
          if removed_names.present?
            InferredConcept.where.not(status: :retired).where(name: removed_names).destroy_all
          end

          new_names = final_result - all_concepts
          if new_names.present?
            InferredConcept.insert_all(new_names.map { |concept| { name: concept } })
          end
        end
      end

      # Extract new concepts from arbitrary content
      # @param content [String] The content to analyze
      # @return [Array<String>] The identified concept names
      def identify_concepts(content)
        DiscourseAi::InferredConcepts::Finder.new.identify_concepts(content)
      end

      # Identify and create concepts from content without applying them to any topic
      # @param content [String] The content to analyze
      # @return [Array<InferredConcept>] The created or found concepts
      def generate_concepts_from_content(content)
        return [] if content.blank?

        # Identify concepts
        finder = DiscourseAi::InferredConcepts::Finder.new
        concept_names = finder.identify_concepts(content)
        return [] if concept_names.blank?

        # Create or find concepts in the database
        finder.create_or_find_concepts(concept_names)
      end

      # Classify a topic in a single pass, matching existing concepts and optionally proposing new ones
      # @param topic [Topic] A Topic instance
      # @param allow_new [Boolean] Whether to stage new candidate concepts
      # @return [Array<InferredConcept>] The concepts that were applied
      def classify_topic(topic, allow_new: true)
        classify_target(
          topic,
          join_model: InferredConceptTopic,
          fk_column: :topic_id,
          allow_new: allow_new,
        )
      end

      # Classify a post in a single pass, matching existing concepts and optionally proposing new ones
      # @param post [Post] A Post instance
      # @param allow_new [Boolean] Whether to stage new candidate concepts
      # @return [Array<InferredConcept>] The concepts that were applied
      def classify_post(post, allow_new: true)
        classify_target(
          post,
          join_model: InferredConceptPost,
          fk_column: :post_id,
          allow_new: allow_new,
        )
      end

      # Generate and apply concepts from a topic's content in a single pass
      # @param topic [Topic] A Topic instance
      # @return [Array<InferredConcept>] The created or matched concepts applied to the topic
      def generate_concepts_from_topic(topic)
        classify_topic(topic, allow_new: true)
      end

      # Generate and apply concepts from a post's content in a single pass
      # @param post [Post] A Post instance
      # @return [Array<InferredConcept>] The created or matched concepts applied to the post
      def generate_concepts_from_post(post)
        classify_post(post, allow_new: true)
      end

      # Match a topic against existing concepts
      # @param topic [Topic] A Topic instance
      # @return [Array<InferredConcept>] The concepts that were applied
      def match_topic_to_concepts(topic)
        classify_topic(topic, allow_new: false)
      end

      # Match a post against existing concepts
      # @param post [Post] A Post instance
      # @return [Array<InferredConcept>] The concepts that were applied
      def match_post_to_concepts(post)
        classify_post(post, allow_new: false)
      end

      # Find topics that have a specific concept (by name or alias)
      # @param concept_name [String] The name or alias of the concept to search for
      # @return [Array<Topic>] Topics that have the specified concept
      def search_topics_by_concept(concept_name)
        concept = ::InferredConcept.by_name_or_alias(concept_name).first
        return [] unless concept
        concept.topics
      end

      # Find posts that have a specific concept (by name or alias)
      # @param concept_name [String] The name or alias of the concept to search for
      # @return [Array<Post>] Posts that have the specified concept
      def search_posts_by_concept(concept_name)
        concept = ::InferredConcept.by_name_or_alias(concept_name).first
        return [] unless concept
        concept.posts
      end

      # Match arbitrary content against retrieved existing concepts
      # @param content [String] The content to analyze
      # @return [Array<String>] Names of matching concepts
      def match_content_to_concepts(content)
        return [] if content.blank? || !DiscourseAi::Embeddings.enabled?

        candidates = CandidateRetriever.new.retrieve(content: content)
        return [] if candidates.empty?

        DiscourseAi::InferredConcepts::Applier.new.match_concepts_to_content(content, candidates)
      rescue CandidateRetriever::EmbeddingsUnavailableError,
             DiscourseAi::Embeddings::ProviderPausedError,
             DiscourseAi::Inference::EmbeddingInferenceError
        []
      end

      # Find candidate topics that are good for concept generation
      #
      # @param opts [Hash] Options to pass to the finder
      # @option opts [Integer] :limit (100) Maximum number of topics to return
      # @option opts [Integer] :min_posts (5) Minimum number of posts in topic
      # @option opts [Integer] :min_likes (10) Minimum number of likes across all posts
      # @option opts [Integer] :min_views (100) Minimum number of views
      # @option opts [Array<Integer>] :exclude_topic_ids ([]) Topic IDs to exclude
      # @option opts [Array<Integer>] :category_ids (nil) Only include topics from these categories
      # @option opts [DateTime] :created_after (30.days.ago) Only include topics created after this time
      # @return [Array<Topic>] Array of Topic objects that are good candidates
      def find_candidate_topics(opts = {})
        DiscourseAi::InferredConcepts::Finder.new.find_candidate_topics(**opts)
      end

      # Find candidate posts that are good for concept generation
      # @param opts [Hash] Options to pass to the finder
      # @return [Array<Post>] Array of Post objects that are good candidates
      def find_candidate_posts(opts = {})
        DiscourseAi::InferredConcepts::Finder.new.find_candidate_posts(**opts)
      end

      private

      def classify_target(target, join_model:, fk_column:, allow_new:)
        return [] if ineligible_target?(target) || !DiscourseAi::Embeddings.enabled?

        applier = Applier.new
        content =
          if target.is_a?(Topic)
            applier.topic_content_for_analysis(target)
          else
            applier.post_content_for_analysis(target)
          end
        return [] if content.blank?

        digest = applier.content_digest(content)
        if join_model.where(fk_column => target.id, :digest => digest).exists?
          return target.inferred_concepts.to_a
        end

        candidates = CandidateRetriever.new.retrieve(content: content, target: target)
        return [] if !allow_new && candidates.empty?

        result = Classifier.new.classify(content, candidates: candidates, allow_new: allow_new)
        candidates_by_id = candidates.index_by(&:id)

        match_entries =
          result[:matches].filter_map do |match|
            concept = candidates_by_id[match[:concept_id]]
            next if concept.nil?

            { concept:, relevance: match[:relevance], primary: match[:primary] }
          end

        if allow_new && result[:proposed_new].present?
          result[:proposed_new].each do |entry|
            concept = resolve_proposed_concept(entry, candidates_by_id: candidates_by_id)
            next if concept.nil?
            next if match_entries.any? { |existing| existing[:concept].id == concept.id }

            match_entries << { concept:, relevance: 0.85, primary: false }
          end
        end

        if match_entries.present? && match_entries.none? { |entry| entry[:primary] }
          match_entries.first[:primary] = true
        end

        applied =
          if target.is_a?(Topic)
            applier.apply_matches_to_topic(target, match_entries, digest: digest)
          else
            applier.apply_matches_to_post(target, match_entries, digest: digest)
          end

        promote_candidates!(applied)
        applied
      rescue CandidateRetriever::EmbeddingsUnavailableError,
             DiscourseAi::Embeddings::ProviderPausedError,
             DiscourseAi::Inference::EmbeddingInferenceError
        []
      end

      def resolve_proposed_concept(entry, candidates_by_id:)
        existing = InferredConcept.by_name_or_alias(entry[:name]).first
        return existing.retired? ? nil : existing if existing

        parent = candidates_by_id[entry[:parent_concept_id]]
        parent = nil if parent&.retired?

        concept =
          InferredConcept.create!(
            name: entry[:name],
            description: entry[:description],
            status: :candidate,
            parent: parent,
          )
        enqueue_concept_embedding(concept)
        concept
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        existing = InferredConcept.by_name_or_alias(entry[:name]).first
        existing&.retired? ? nil : existing
      end

      def promote_candidates!(concepts)
        concepts.each do |concept|
          next unless concept.candidate?

          usage_count =
            InferredConceptTopic.where(inferred_concept_id: concept.id).count +
              InferredConceptPost.where(inferred_concept_id: concept.id).count
          next if usage_count < PROMOTION_THRESHOLD

          concept.active!
          enqueue_concept_embedding(concept)
        end
      end

      def enqueue_concept_embedding(concept)
        return unless DiscourseAi::Embeddings.enabled?

        Jobs.enqueue(:generate_embeddings, target_type: "InferredConcept", target_id: concept.id)
      end

      def ineligible_target?(target)
        return true if target.blank?

        topic = target.is_a?(Topic) ? target : target.topic
        target.deleted_at.present? || topic.nil? || topic.deleted_at.present? ||
          topic.private_message?
      end
    end
  end
end
