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
        if search_query.blank? &&
             has_any_filter?(category, user, order, tags, before, after, status)
          return(
            fallback_to_filter(
              category: category,
              user: user,
              order: order,
              tags: tags,
              before: before,
              after: after,
              status: status,
              max_results: max_results,
              current_user: current_user,
              result_style: result_style,
            )
          )
        end

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
          SiteSetting.ai_embeddings_enabled && SiteSetting.ai_embeddings_semantic_search_enabled &&
            search_query.present?

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
            row = {
              title: post.topic.title,
              url: Discourse.base_path + post.url,
              username: post.user&.username,
              excerpt: post.excerpt,
              created: post.created_at,
              category: category_breadcrumb(post.topic.category),
              likes: post.like_count,
              topic_views: post.topic.views,
              topic_likes: post.topic.like_count,
              topic_replies: post.topic.posts_count - 1,
            }

            hidden_tags ||= DiscourseTagging.hidden_tag_names
            tag_names = visible_tag_names(post.topic.tags, hidden_tags)
            row[:tags] = tag_names if tag_names

            row
          end
        end
      end

      def self.order_to_filter_syntax(order)
        case order&.to_s
        when "latest", "latest_topic"
          "order:activity"
        when "oldest"
          "order:created-asc"
        when "views"
          "order:views"
        when "likes"
          "order:likes"
        end
      end

      def self.has_any_filter?(category, user, order, tags, before, after, status)
        [category, user, order, tags, before, after, status].any?(&:present?)
      end

      def self.fallback_to_filter(
        category:,
        user:,
        order:,
        tags:,
        before:,
        after:,
        status:,
        max_results:,
        current_user:,
        result_style:
      )
        guardian = current_user ? Guardian.new(current_user) : Guardian.new

        query_parts = []
        query_parts << "category:#{category}" if category.present?
        if order.present? && order_to_filter_syntax(order)
          query_parts << order_to_filter_syntax(order)
        end
        query_parts << "tags:#{tags}" if tags.present?
        query_parts << "users:#{user}" if user.present?
        query_parts << "created-before:#{before}" if before.present?
        query_parts << "created-after:#{after}" if after.present?
        query_parts << "status:#{status}" if status.present?

        return empty_results if query_parts.blank?

        # Start with listable, visible topics and apply category permission filtering
        # This follows the same pattern as TopicQuery - filter_allowed_categories handles
        # read_restricted categories and respects admin settings
        scope = Topic.listable_topics.visible
        scope = guardian.filter_allowed_categories(scope, category_id_column: "topics.category_id")

        filter = TopicsFilter.new(guardian: guardian, scope: scope)
        topics = filter.filter_from_query_string(query_parts.join(" "))
        topics =
          topics.includes(:category, :user, :tags).limit(max_results.to_i) if max_results.to_i > 0

        format_filter_results(
          topics,
          query_string: query_parts.join(" "),
          result_style: result_style,
          category: category,
          user: user,
          order: order,
          tags: tags,
          before: before,
          after: after,
          status: status,
          max_results: max_results,
        )
      end

      def self.format_filter_results(
        topics,
        query_string:,
        result_style:,
        category:,
        user:,
        order:,
        tags:,
        before:,
        after:,
        status:,
        max_results:
      )
        hidden_tags = nil

        search_args = {
          search_query: nil,
          category: category,
          user: user,
          order: order,
          tags: tags,
          before: before,
          after: after,
          status: status,
          max_results: max_results,
        }.compact

        if topics.blank?
          {
            args: search_args,
            rows: [],
            instruction: "nothing was found, expand your search",
            filter_query: query_string,
          }
        else
          result =
            format_results(topics, args: search_args, result_style: result_style) do |topic|
              row = {
                title: topic.title,
                url: Discourse.base_path + topic.relative_url,
                username: topic.user&.username,
                excerpt: topic.excerpt,
                created: topic.created_at,
                category: category_breadcrumb(topic.category),
                likes: topic.like_count,
                topic_views: topic.views,
                topic_likes: topic.like_count,
                topic_replies: topic.posts_count - 1,
              }

              hidden_tags ||= DiscourseTagging.hidden_tag_names
              tag_names = visible_tag_names(topic.tags, hidden_tags)
              row[:tags] = tag_names if tag_names

              row
            end
          result[:filter_query] = query_string
          result
        end
      end

      def self.empty_results
        { args: {}, rows: [], instruction: "nothing was found, expand your search" }
      end

      def self.category_breadcrumb(category)
        [category&.parent_category&.name, category&.name].compact.join(" > ")
      end

      def self.visible_tag_names(tags, hidden_tags)
        return nil unless SiteSetting.tagging_enabled && tags.present?
        visible = tags.map(&:name) - hidden_tags
        visible.presence&.join(", ")
      end

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
