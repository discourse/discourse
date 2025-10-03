# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Finder
      # Identifies potential concepts from provided content
      # Returns an array of concept names (strings)
      def identify_concepts(content)
        return [] if content.blank?

        # Use the ConceptFinder persona to identify concepts
        persona =
          AiPersona
            .all_personas(enabled_only: false)
            .find { |p| p.id == SiteSetting.inferred_concepts_generate_persona.to_i }
            .new

        llm = LlmModel.find(persona.class.default_llm_id)
        context =
          DiscourseAi::Personas::BotContext.new(
            messages: [{ type: :user, content: content }],
            user: Discourse.system_user,
            inferred_concepts: DiscourseAi::InferredConcepts::Manager.new.list_concepts,
          )

        bot = DiscourseAi::Personas::Bot.as(Discourse.system_user, persona: persona, model: llm)
        structured_output = nil

        bot.reply(context) do |partial, _, type|
          structured_output = partial if type == :structured_output
        end

        structured_output&.read_buffered_property(:concepts) || []
      end

      # Creates or finds concepts in the database from provided names
      # Returns an array of InferredConcept instances
      def create_or_find_concepts(concept_names)
        return [] if concept_names.blank?

        concept_names.map { |name| InferredConcept.find_or_create_by(name: name) }
      end

      # Finds candidate topics to use for concept generation
      #
      # @param limit [Integer] Maximum number of topics to return
      # @param min_posts [Integer] Minimum number of posts in topic
      # @param min_likes [Integer] Minimum number of likes across all posts
      # @param min_views [Integer] Minimum number of views
      # @param exclude_topic_ids [Array<Integer>] Topic IDs to exclude
      # @param category_ids [Array<Integer>] Only include topics from these categories (optional)
      # @param created_after [DateTime] Only include topics created after this time (optional)
      # @return [Array<Topic>] Array of Topic objects that are good candidates
      def find_candidate_topics(
        limit: 100,
        min_posts: 5,
        min_likes: 10,
        min_views: 100,
        exclude_topic_ids: [],
        category_ids: nil,
        created_after: 30.days.ago
      )
        query =
          Topic.where(
            "topics.posts_count >= ? AND topics.views >= ? AND topics.like_count >= ?",
            min_posts,
            min_views,
            min_likes,
          )

        # Apply additional filters
        query = query.where("topics.id NOT IN (?)", exclude_topic_ids) if exclude_topic_ids.present?
        query = query.where("topics.category_id IN (?)", category_ids) if category_ids.present?
        query = query.where("topics.created_at >= ?", created_after) if created_after.present?

        # Exclude PM topics (if they exist in Discourse)
        query = query.where(archetype: Archetype.default)

        # Exclude topics that already have concepts
        topics_with_concepts = <<~SQL
          SELECT DISTINCT topic_id
          FROM inferred_concept_topics
        SQL

        query = query.where("topics.id NOT IN (#{topics_with_concepts})")

        # Score and order topics by engagement (combination of views, likes, and posts)
        query =
          query.select(
            "topics.*,
          (topics.like_count * 2 + topics.posts_count * 3 + topics.views * 0.1) AS engagement_score",
          ).order("engagement_score DESC")

        # Return limited number of topics
        query.limit(limit)
      end

      # Find candidate posts that are good for concept generation
      #
      # @param limit [Integer] Maximum number of posts to return
      # @param min_likes [Integer] Minimum number of likes
      # @param exclude_first_posts [Boolean] Exclude first posts in topics
      # @param exclude_post_ids [Array<Integer>] Post IDs to exclude
      # @param category_ids [Array<Integer>] Only include posts from topics in these categories
      # @param created_after [DateTime] Only include posts created after this time
      # @return [Array<Post>] Array of Post objects that are good candidates
      def find_candidate_posts(
        limit: 100,
        min_likes: 5,
        exclude_first_posts: true,
        exclude_post_ids: [],
        category_ids: nil,
        created_after: 30.days.ago
      )
        query = Post.where("posts.like_count >= ?", min_likes)

        # Exclude first posts if specified
        query = query.where("posts.post_number > 1") if exclude_first_posts

        # Apply additional filters
        query = query.where("posts.id NOT IN (?)", exclude_post_ids) if exclude_post_ids.present?
        query = query.where("posts.created_at >= ?", created_after) if created_after.present?

        # Filter by category if specified
        if category_ids.present?
          query = query.joins(:topic).where("topics.category_id IN (?)", category_ids)
        end

        # Exclude posts that already have concepts
        posts_with_concepts = <<~SQL
          SELECT DISTINCT post_id
          FROM inferred_concept_posts
        SQL

        query = query.where("posts.id NOT IN (#{posts_with_concepts})")

        # Order by engagement (likes)
        query = query.order(like_count: :desc)

        # Return limited number of posts
        query.limit(limit)
      end

      # Deduplicate and standardize a list of concepts
      # @param concept_names [Array<String>] List of concept names to deduplicate
      # @return [Hash] Hash with deduplicated concepts and mapping
      def deduplicate_concepts(concept_names)
        return { deduplicated_concepts: [], mapping: {} } if concept_names.blank?

        # Use the ConceptDeduplicator persona to deduplicate concepts
        persona =
          AiPersona
            .all_personas(enabled_only: false)
            .find { |p| p.id == SiteSetting.inferred_concepts_deduplicate_persona.to_i }
            .new

        llm = LlmModel.find(persona.class.default_llm_id)

        # Create the input for the deduplicator
        input = { type: :user, content: concept_names.join(", ") }

        context =
          DiscourseAi::Personas::BotContext.new(messages: [input], user: Discourse.system_user)

        bot = DiscourseAi::Personas::Bot.as(Discourse.system_user, persona: persona, model: llm)
        structured_output = nil

        bot.reply(context) do |partial, _, type|
          structured_output = partial if type == :structured_output
        end

        structured_output&.read_buffered_property(:streamlined_tags) || []
      end
    end
  end
end
