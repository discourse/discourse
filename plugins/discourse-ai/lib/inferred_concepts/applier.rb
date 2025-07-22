# frozen_string_literal: true

module DiscourseAi
  module InferredConcepts
    class Applier
      # Associates the provided concepts with a topic
      # topic: a Topic instance
      # concepts: an array of InferredConcept instances
      def apply_to_topic(topic, concepts)
        return if topic.blank? || concepts.blank?

        topic.inferred_concepts << concepts
      end

      # Associates the provided concepts with a post
      # post: a Post instance
      # concepts: an array of InferredConcept instances
      def apply_to_post(post, concepts)
        return if post.blank? || concepts.blank?

        post.inferred_concepts << concepts
      end

      # Extracts content from a topic for concept analysis
      # Returns a string with the topic title and first few posts
      def topic_content_for_analysis(topic)
        return "" if topic.blank?

        # Combine title and first few posts for analysis
        posts = Post.where(topic_id: topic.id).order(:post_number).limit(10)

        content = "Title: #{topic.title}\n\n"
        content += posts.map { |p| "#{p.post_number}) #{p.user.username}: #{p.raw}" }.join("\n\n")

        content
      end

      # Extracts content from a post for concept analysis
      # Returns a string with the post content
      def post_content_for_analysis(post)
        return "" if post.blank?

        # Get the topic title for context
        topic_title = post.topic&.title || ""

        content = "Topic: #{topic_title}\n\n"
        content += "Post by #{post.user.username}:\n#{post.raw}"

        content
      end

      # Match a topic with existing concepts
      def match_existing_concepts(topic)
        return [] if topic.blank?

        # Get content to analyze
        content = topic_content_for_analysis(topic)

        # Get all existing concepts
        existing_concepts = DiscourseAi::InferredConcepts::Manager.new.list_concepts
        return [] if existing_concepts.empty?

        # Use the ConceptMatcher persona to match concepts
        matched_concept_names = match_concepts_to_content(content, existing_concepts)

        # Find concepts in the database
        matched_concepts = InferredConcept.where(name: matched_concept_names)

        # Apply concepts to the topic
        apply_to_topic(topic, matched_concepts)

        matched_concepts
      end

      # Match a post with existing concepts
      def match_existing_concepts_for_post(post)
        return [] if post.blank?

        # Get content to analyze
        content = post_content_for_analysis(post)

        # Get all existing concepts
        existing_concepts = DiscourseAi::InferredConcepts::Manager.new.list_concepts
        return [] if existing_concepts.empty?

        # Use the ConceptMatcher persona to match concepts
        matched_concept_names = match_concepts_to_content(content, existing_concepts)

        # Find concepts in the database
        matched_concepts = InferredConcept.where(name: matched_concept_names)

        # Apply concepts to the post
        apply_to_post(post, matched_concepts)

        matched_concepts
      end

      # Use ConceptMatcher persona to match content against provided concepts
      def match_concepts_to_content(content, concept_list)
        return [] if content.blank? || concept_list.blank?

        # Prepare user message with only the content
        user_message = content

        # Use the ConceptMatcher persona to match concepts

        persona =
          AiPersona
            .all_personas(enabled_only: false)
            .find { |p| p.id == SiteSetting.inferred_concepts_match_persona.to_i }
            .new

        llm = LlmModel.find(persona.class.default_llm_id)

        input = { type: :user, content: content }

        context =
          DiscourseAi::Personas::BotContext.new(
            messages: [input],
            user: Discourse.system_user,
            inferred_concepts: concept_list,
          )

        bot = DiscourseAi::Personas::Bot.as(Discourse.system_user, persona: persona, model: llm)
        structured_output = nil

        bot.reply(context) do |partial, _, type|
          structured_output = partial if type == :structured_output
        end

        structured_output&.read_buffered_property(:matching_concepts) || []
      end
    end
  end
end
