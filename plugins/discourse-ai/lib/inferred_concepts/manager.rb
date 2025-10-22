# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Manager
      # Get a list of existing concepts
      # @param limit [Integer, nil] Optional maximum number of concepts to return
      # @return [Array<InferredConcept>] Array of InferredConcept objects
      def list_concepts(limit: nil)
        query = InferredConcept.all.order("name ASC")

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

          # Apply the deduplicated concepts
          InferredConcept.where.not(name: final_result).destroy_all
          InferredConcept.insert_all(final_result.map { |concept| { name: concept } })
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

      # Generate concepts from a topic's content without applying them to the topic
      # @param topic [Topic] A Topic instance
      # @return [Array<InferredConcept>] The created or found concepts
      def generate_concepts_from_topic(topic)
        return [] if topic.blank?

        # Get content to analyze
        applier = DiscourseAi::InferredConcepts::Applier.new
        content = applier.topic_content_for_analysis(topic)
        return [] if content.blank?

        # Generate concepts from the content
        generate_concepts_from_content(content)
      end

      # Generate concepts from a post's content without applying them to the post
      # @param post [Post] A Post instance
      # @return [Array<InferredConcept>] The created or found concepts
      def generate_concepts_from_post(post)
        return [] if post.blank?

        # Get content to analyze
        applier = DiscourseAi::InferredConcepts::Applier.new
        content = applier.post_content_for_analysis(post)
        return [] if content.blank?

        # Generate concepts from the content
        generate_concepts_from_content(content)
      end

      # Match a topic against existing concepts
      # @param topic [Topic] A Topic instance
      # @return [Array<InferredConcept>] The concepts that were applied
      def match_topic_to_concepts(topic)
        return [] if topic.blank?

        DiscourseAi::InferredConcepts::Applier.new.match_existing_concepts(topic)
      end

      # Match a post against existing concepts
      # @param post [Post] A Post instance
      # @return [Array<InferredConcept>] The concepts that were applied
      def match_post_to_concepts(post)
        return [] if post.blank?

        DiscourseAi::InferredConcepts::Applier.new.match_existing_concepts_for_post(post)
      end

      # Find topics that have a specific concept
      # @param concept_name [String] The name of the concept to search for
      # @return [Array<Topic>] Topics that have the specified concept
      def search_topics_by_concept(concept_name)
        concept = ::InferredConcept.find_by(name: concept_name)
        return [] unless concept
        concept.topics
      end

      # Find posts that have a specific concept
      # @param concept_name [String] The name of the concept to search for
      # @return [Array<Post>] Posts that have the specified concept
      def search_posts_by_concept(concept_name)
        concept = ::InferredConcept.find_by(name: concept_name)
        return [] unless concept
        concept.posts
      end

      # Match arbitrary content against existing concepts
      # @param content [String] The content to analyze
      # @return [Array<String>] Names of matching concepts
      def match_content_to_concepts(content)
        existing_concepts = InferredConcept.all.pluck(:name)
        return [] if existing_concepts.empty?

        DiscourseAi::InferredConcepts::Applier.new.match_concepts_to_content(
          content,
          existing_concepts,
        )
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
    end
  end
end
