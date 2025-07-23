# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class EmbeddingsController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      SEMANTIC_SEARCH_TYPE = "semantic_search"

      MAX_HYDE_SEARCHES_PER_MINUTE = 4
      MAX_SEARCHES_PER_MINUTE = 100

      def search
        query = params[:q].to_s
        skip_hyde = params[:hyde].to_s.downcase == "false" || params[:hyde].to_s == "0"

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

        if !skip_hyde && !semantic_search.cached_query?(query)
          RateLimiter.new(
            current_user,
            "semantic-search",
            MAX_HYDE_SEARCHES_PER_MINUTE,
            1.minutes,
          ).performed!
        else
          RateLimiter.new(
            current_user,
            "semantic-search-non-hyde",
            MAX_SEARCHES_PER_MINUTE,
            1.minutes,
          ).performed!
        end

        hijack do
          begin
            semantic_search
              .search_for_topics(query, _page = 1, hyde: !skip_hyde)
              .each { |topic_post| grouped_results.add(topic_post) }

            render_serialized(
              grouped_results,
              GroupedSearchResultSerializer,
              result: grouped_results,
            )
          rescue Discourse::InvalidAccess
            render_json_error(I18n.t("invalid_access"), status: 403)
          end
        end
      end

      def quick_search
        # this search function searches posts (vs: topics)
        # it requires post embeddings and a reranker
        # it will not perform a hyde expantion
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
          )

        semantic_search = DiscourseAi::Embeddings::SemanticSearch.new(guardian)

        if !semantic_search.cached_query?(query)
          RateLimiter.new(current_user, "semantic-search", 60, 1.minutes).performed!
        end

        hijack do
          semantic_search.quick_search(query).each { |topic_post| grouped_results.add(topic_post) }

          render_serialized(grouped_results, GroupedSearchResultSerializer, result: grouped_results)
        end
      end
    end
  end
end
