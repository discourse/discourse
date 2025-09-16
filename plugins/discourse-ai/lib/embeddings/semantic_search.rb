# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class SemanticSearch
      def self.clear_cache_for(query)
        digest = OpenSSL::Digest::SHA1.hexdigest(query)

        hyde_model_id = find_ai_hyde_model_id
        hyde_key = "semantic-search-#{digest}-#{hyde_model_id}"

        Discourse.cache.delete(hyde_key)
        Discourse.cache.delete("#{hyde_key}-#{SiteSetting.ai_embeddings_selected_model}")
        Discourse.cache.delete("-#{SiteSetting.ai_embeddings_selected_model}")
      end

      def initialize(guardian)
        @guardian = guardian
      end

      def cached_query?(query)
        digest = OpenSSL::Digest::SHA1.hexdigest(query)
        hyde_model_id = self.class.find_ai_hyde_model_id
        embedding_key =
          build_embedding_key(digest, hyde_model_id, SiteSetting.ai_embeddings_selected_model)

        Discourse.cache.read(embedding_key).present?
      end

      def vector
        @vector ||= DiscourseAi::Embeddings::Vector.instance
      end

      def hyde_embedding(search_term)
        digest = OpenSSL::Digest::SHA1.hexdigest(search_term)
        hyde_model_id = self.class.find_ai_hyde_model_id
        hyde_key = build_hyde_key(digest, hyde_model_id)

        embedding_key =
          build_embedding_key(digest, hyde_model_id, SiteSetting.ai_embeddings_selected_model)

        hypothetical_post =
          Discourse
            .cache
            .fetch(hyde_key, expires_in: 1.week) { hypothetical_post_from(search_term) }

        Discourse
          .cache
          .fetch(embedding_key, expires_in: 1.week) { vector.vector_from(hypothetical_post) }
      end

      def embedding(search_term, asymmetric: false)
        digest = OpenSSL::Digest::SHA1.hexdigest(search_term)
        embedding_key = build_embedding_key(digest, "", SiteSetting.ai_embeddings_selected_model)

        Discourse
          .cache
          .fetch(embedding_key, expires_in: 1.week) { vector.vector_from(search_term, asymmetric) }
      end

      # this ensures the candidate topics are over selected
      # that way we have a much better chance of finding topics
      # if the user filtered the results or index is a bit out of date
      OVER_SELECTION_FACTOR = 4

      def search_for_topics(query, page = 1, hyde: true)
        max_results_per_page = 100
        limit = [Search.per_filter, max_results_per_page].min + 1
        offset = (page - 1) * limit
        search = Search.new(query, { guardian: guardian })
        search_term = search.term

        if search_term.blank? || search_term.length < SiteSetting.min_search_term_length
          return Post.none
        end

        search_embedding = nil
        if hyde
          search_embedding = hyde_embedding(search_term)
        else
          search_embedding = embedding(search_term, asymmetric: true)
        end

        over_selection_limit = limit * OVER_SELECTION_FACTOR

        schema = DiscourseAi::Embeddings::Schema.for(Topic)

        candidate_topic_ids =
          schema.asymmetric_similarity_search(
            search_embedding,
            limit: over_selection_limit,
            offset: offset,
          ).map(&:topic_id)

        semantic_results =
          ::Post
            .where(post_type: ::Topic.visible_post_types(guardian.user))
            .public_posts
            .where("topics.visible")
            .where(topic_id: candidate_topic_ids, post_number: 1)
            .order("array_position(ARRAY#{candidate_topic_ids}, posts.topic_id)")
            .limit(limit)

        query_filter_results = search.apply_filters(semantic_results)

        guardian.filter_allowed_categories(query_filter_results)
      end

      def similar_topic_ids_to(query, candidates:)
        # NOTE: candidates may be a very large relation, be deliberate that only first is selected
        return [] if candidates.limit(1).empty?

        over_selection_limit = ::Topic::SIMILAR_TOPIC_LIMIT * OVER_SELECTION_FACTOR
        asymmetric = true
        search_embedding = vector.vector_from(query, asymmetric)

        schema = DiscourseAi::Embeddings::Schema.for(Topic)

        candidate_topic_ids =
          schema.asymmetric_similarity_search(
            search_embedding,
            limit: over_selection_limit,
            offset: 0,
          ).map(&:topic_id)

        candidates.where(id: candidate_topic_ids).pluck(:id)
      end

      def quick_search(query)
        max_semantic_results_per_page = 100
        search = Search.new(query, { guardian: guardian })
        search_term = search.term
        hyde_model_id = self.class.find_ai_hyde_model_id

        return [] if search_term.nil? || search_term.length < SiteSetting.min_search_term_length

        vector = DiscourseAi::Embeddings::Vector.instance

        digest = OpenSSL::Digest::SHA1.hexdigest(search_term)

        embedding_key =
          build_embedding_key(digest, hyde_model_id, SiteSetting.ai_embeddings_selected_model)

        search_term_embedding =
          Discourse
            .cache
            .fetch(embedding_key, expires_in: 1.week) do
              vector.vector_from(search_term, asymmetric: true)
            end

        candidate_post_ids =
          DiscourseAi::Embeddings::Schema
            .for(Post)
            .asymmetric_similarity_search(
              search_term_embedding,
              limit: max_semantic_results_per_page,
              offset: 0,
            )
            .map(&:post_id)

        semantic_results =
          ::Post
            .where(post_type: ::Topic.visible_post_types(guardian.user))
            .public_posts
            .where("topics.visible")
            .where(id: candidate_post_ids)
            .order("array_position(ARRAY#{candidate_post_ids}, posts.id)")

        filtered_results = search.apply_filters(semantic_results)

        rerank_posts_payload =
          filtered_results
            .map(&:cooked)
            .map { Nokogiri::HTML5.fragment(_1).text }
            .map { _1.truncate(2000, omission: "") }

        reranked_results =
          DiscourseAi::Inference::HuggingFaceTextEmbeddings.rerank(
            search_term,
            rerank_posts_payload,
          )

        reordered_ids = reranked_results.map { _1[:index] }.map { filtered_results[_1].id }.take(5)

        reranked_semantic_results =
          ::Post
            .where(post_type: ::Topic.visible_post_types(guardian.user))
            .public_posts
            .where("topics.visible")
            .where(id: reordered_ids)
            .order("array_position(ARRAY#{reordered_ids}, posts.id)")

        guardian.filter_allowed_categories(reranked_semantic_results)
      end

      def hypothetical_post_from(search_term)
        context =
          DiscourseAi::Personas::BotContext.new(
            user: @guardian.user,
            skip_tool_details: true,
            feature_name: "semantic_search_hyde",
            messages: [{ type: :user, content: search_term }],
          )

        bot = build_bot(@guardian.user)
        return nil if bot.nil?

        structured_output = nil
        raw_response = +""
        hyde_schema_key = bot.persona.response_format&.first.to_h

        buffer_blk =
          Proc.new do |partial, _, type|
            if type == :structured_output
              structured_output = partial
            elsif type.blank?
              # Assume response is a regular completion.
              raw_response << partial
            end
          end

        bot.reply(context, &buffer_blk)

        structured_output&.read_buffered_property(hyde_schema_key["key"]&.to_sym) || raw_response
      end

      # Priorities are:
      #   1. Persona's default LLM
      #   2. SiteSetting.ai_default_llm_model (or newest LLM if not set)
      def find_ai_hyde_model(persona_klass)
        model_id = persona_klass.default_llm_id || SiteSetting.ai_default_llm_model

        model_id.present? ? LlmModel.find_by(id: model_id) : LlmModel.last
      end

      def self.find_ai_hyde_model_id
        persona_llm_id =
          AiPersona.find_by(
            id: SiteSetting.ai_embeddings_semantic_search_hyde_persona,
          )&.default_llm_id

        if persona_llm_id.present?
          persona_llm_id
        else
          SiteSetting.ai_default_llm_model.to_i || LlmModel.last&.id
        end
      end

      private

      attr_reader :guardian

      def build_hyde_key(digest, hyde_model)
        "semantic-search-#{digest}-#{hyde_model}"
      end

      def build_embedding_key(digest, hyde_model, embedding_model)
        "#{build_hyde_key(digest, hyde_model)}-#{embedding_model}"
      end

      def build_bot(user)
        persona_id = SiteSetting.ai_embeddings_semantic_search_hyde_persona

        persona_klass = AiPersona.find_by(id: persona_id)&.class_instance
        return if persona_klass.nil?

        llm_model = find_ai_hyde_model(persona_klass)
        return if llm_model.nil?

        DiscourseAi::Personas::Bot.as(user, persona: persona_klass.new, model: llm_model)
      end
    end
  end
end
