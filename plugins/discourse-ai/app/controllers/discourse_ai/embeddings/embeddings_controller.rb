# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class EmbeddingsController < ::ApplicationController
      requires_plugin PLUGIN_NAME

      SEMANTIC_SEARCH_TYPE = "semantic_search"

      MAX_HYDE_SEARCHES_PER_MINUTE = 4
      MAX_SEARCHES_PER_MINUTE = 100

      def search
        query = params[:q].to_s
        use_hyde = SiteSetting.ai_embeddings_semantic_search_use_hyde

        if params[:hyde].present? &&
             (params[:hyde].to_s.downcase == "false" || params[:hyde].to_s == "0")
          use_hyde = false
        end

        if query.length < SiteSetting.min_search_term_length
          raise Discourse::InvalidParameters.new(:q)
        end

        grouped_results =
          Search::GroupedSearchResults.new(
            type_filter: SEMANTIC_SEARCH_TYPE,
            term: query,
            search_context: guardian,
            use_pg_headlines_for_excerpt: false,
            can_lazy_load_categories: guardian.can_lazy_load_categories?,
          )

        semantic_search = DiscourseAi::Embeddings::SemanticSearch.new(guardian)

        if use_hyde && !semantic_search.cached_query?(query)
          RateLimiter.new(
            current_user,
            "semantic-search",
            MAX_HYDE_SEARCHES_PER_MINUTE,
            1.minute,
          ).performed!
        else
          RateLimiter.new(
            current_user,
            "semantic-search-non-hyde",
            MAX_SEARCHES_PER_MINUTE,
            1.minute,
          ).performed!
        end

        hijack do
          begin
            semantic_search
              .search_for_topics(query, _page = 1, hyde: use_hyde)
              .each { |topic_post| grouped_results.add(topic_post) }
          rescue Discourse::InvalidAccess
            return render_json_error(I18n.t("invalid_access"), status: 403)
          rescue Net::HTTPBadResponse => e
            Rails.logger.warn("Semantic search embedding generation failed: #{e.message}")
          end

          render_serialized(grouped_results, GroupedSearchResultSerializer, result: grouped_results)
        end
      end

      def quick_search
        query = params[:q].to_s

        if query.length < SiteSetting.min_search_term_length
          raise Discourse::InvalidParameters.new(:q)
        end

        grouped_results =
          Search::GroupedSearchResults.new(
            type_filter: SEMANTIC_SEARCH_TYPE,
            term: query,
            search_context: guardian,
            use_pg_headlines_for_excerpt: false,
            can_lazy_load_categories: guardian.can_lazy_load_categories?,
          )

        semantic_search = DiscourseAi::Embeddings::SemanticSearch.new(guardian)

        if !semantic_search.cached_query?(query)
          RateLimiter.new(current_user, "semantic-search", 60, 1.minute).performed!
        end

        hijack do
          begin
            semantic_search
              .search_for_topics(query, _page = 1, hyde: false)
              .each { |topic_post| grouped_results.add(topic_post) }
          rescue Net::HTTPBadResponse => e
            Rails.logger.warn("Quick search embedding generation failed: #{e.message}")
          end

          render_serialized(grouped_results, GroupedSearchResultSerializer, result: grouped_results)
        end
      end
    end
  end
end
