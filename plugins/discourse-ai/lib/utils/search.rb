# frozen_string_literal: true

module DiscourseAi
  module Utils
    class Search
      def self.perform_search(
        search_query: nil,
        category: nil,
        user: nil,
        order: nil,
        max_posts: nil,
        tags: nil,
        before: nil,
        after: nil,
        status: nil,
        hyde: true,
        max_results: 20,
        current_user: nil,
        result_style: :compact
      )
        search_terms = []

        search_terms << search_query.strip if search_query.present?
        search_terms << "category:#{category}" if category.present?
        search_terms << "user:#{user}" if user.present?
        search_terms << "order:#{order}" if order.present?
        search_terms << "max_posts:#{max_posts}" if max_posts.present?
        search_terms << "tags:#{tags}" if tags.present?
        search_terms << "before:#{before}" if before.present?
        search_terms << "after:#{after}" if after.present?
        search_terms << "status:#{status}" if status.present?

        guardian = Guardian.new(current_user)

        search_string = search_terms.join(" ").to_s

        begin
          results = ::Search.execute(search_string, search_type: :full_page, guardian: guardian)
        rescue Discourse::InvalidAccess => e
          return(
            {
              args: {
                search_query: search_query,
                category: category,
                user: user,
                order: order,
                max_posts: max_posts,
                tags: tags,
                before: before,
                after: after,
                status: status,
                max_results: max_results,
              }.compact,
              rows: [],
              instruction: I18n.t("invalid_access"),
              error: e.message,
            }
          )
        end

        results_limit = max_results

        should_try_semantic_search =
          SiteSetting.ai_embeddings_semantic_search_enabled && search_query.present?

        max_semantic_results = max_results / 4
        results_limit = results_limit - max_semantic_results if should_try_semantic_search

        posts = results&.posts || []
        posts = posts[0..results_limit.to_i - 1]

        if should_try_semantic_search
          semantic_search = DiscourseAi::Embeddings::SemanticSearch.new(guardian)
          topic_ids = Set.new(posts.map(&:topic_id))

          search = ::Search.new(search_string, guardian: guardian)

          semantic_results = nil
          begin
            semantic_results = semantic_search.search_for_topics(search.term, hyde: hyde)
          rescue => e
            Discourse.warn_exception(e, message: "Semantic search failed")
          end

          if semantic_results
            semantic_results = search.apply_filters(semantic_results)

            semantic_results.each do |post|
              next if topic_ids.include?(post.topic_id)

              topic_ids << post.topic_id
              posts << post

              break if posts.length >= max_results
            end
          end
        end

        hidden_tags = nil

        # Construct search_args hash for consistent return format
        search_args = {
          search_query: search_query,
          category: category,
          user: user,
          order: order,
          max_posts: max_posts,
          tags: tags,
          before: before,
          after: after,
          status: status,
          max_results: max_results,
        }.compact

        if posts.blank?
          { args: search_args, rows: [], instruction: "nothing was found, expand your search" }
        else
          format_results(posts, args: search_args, result_style: result_style) do |post|
            category_names = [
              post.topic.category&.parent_category&.name,
              post.topic.category&.name,
            ].compact.join(" > ")
            row = {
              title: post.topic.title,
              url: Discourse.base_path + post.url,
              username: post.user&.username,
              excerpt: post.excerpt,
              created: post.created_at,
              category: category_names,
              likes: post.like_count,
              topic_views: post.topic.views,
              topic_likes: post.topic.like_count,
              topic_replies: post.topic.posts_count - 1,
            }

            if SiteSetting.tagging_enabled
              hidden_tags ||= DiscourseTagging.hidden_tag_names
              tags = post.topic.tags.map(&:name) - hidden_tags
              row[:tags] = tags.join(", ") if tags.present?
            end

            row
          end
        end
      end

      private

      def self.format_results(rows, args: nil, result_style:)
        rows = rows&.map { |row| yield row } if block_given?
        column_names = nil

        if result_style == :compact
          index = -1
          column_indexes = {}

          rows =
            rows&.map do |data|
              new_row = []
              data.each do |key, value|
                found_index = column_indexes[key.to_s] ||= (index += 1)
                new_row[found_index] = value
              end
              new_row
            end
          column_names = column_indexes.keys
        end

        result = { rows: rows }
        result[:column_names] = column_names if column_names
        result[:args] = args if args
        result
      end
    end
  end
end
