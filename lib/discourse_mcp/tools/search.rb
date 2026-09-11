# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class Search
      def self.call(arguments:, request_context:)
        query = arguments.fetch("query").to_s
        limit = arguments.fetch("max_results", 10)
        results = ::Search.execute(query, guardian: request_context.guardian)
        topics = results.posts.filter_map(&:topic).uniq(&:id).first(limit + 1)
        has_more = topics.length > limit
        topics = topics.first(limit)
        ToolHelpers.text_and_structured(
          results: topics.map { |topic| topic.slice(:id, :slug, :title).symbolize_keys },
          meta: {
            total: topics.length,
            has_more:,
          },
        )
      end
    end

    class FilterTopics
      TOP_PERIODS = %w[daily weekly monthly quarterly yearly all].freeze

      def self.call(arguments:, request_context:)
        view = arguments.fetch("view", "filtered")
        filter = arguments["filter"]&.strip
        top_period = arguments["top_period"]
        page = arguments.fetch("page", 0)
        per_page = arguments.fetch("per_page", 20)
        validate_arguments!(view:, filter:, top_period:)

        period = view == "hot" ? "daily" : (top_period || "weekly" if view == "top")
        topics = topic_page(view:, filter:, period:, page:, per_page:, request_context:)
        next_topics =
          topic_page(
            view:,
            filter:,
            period:,
            page: (page + 1) * per_page,
            per_page: 1,
            request_context:,
          )

        visible_tag_ids = ToolHelpers.visible_tag_ids(topics, request_context.guardian)
        results = topics.map { |topic| ToolHelpers.discovery_topic_json(topic, visible_tag_ids) }
        ToolHelpers.text_and_structured(
          results:,
          meta: {
            view:,
            top_period: period,
            page:,
            per_page:,
            returned: results.length,
            has_more: next_topics.present?,
          },
        )
      end

      def self.validate_arguments!(view:, filter:, top_period:)
        if view == "filtered" && filter.blank?
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.filter_required")
        end
        if view != "filtered" && filter.present?
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.filter_only_for_filtered_view")
        end
        if view != "top" && top_period.present?
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.top_period_only_for_top_view")
        end
      end
      private_class_method :validate_arguments!

      def self.topic_page(view:, filter:, period:, page:, per_page:, request_context:)
        options = { page:, per_page: }
        options[:q] = filter if view == "filtered"
        query = TopicQuery.new(request_context.user, options)
        list =
          if view == "filtered"
            query.list_filter
          else
            query.list_top_for(period.to_sym)
          end
        list.topics
      end
      private_class_method :topic_page
    end

    class SearchPosts
      def self.call(arguments:, request_context:)
        query = arguments.fetch("query")
        page = arguments.fetch("page", 1)
        guardian = request_context.guardian
        results =
          ::Search.execute(
            query,
            guardian:,
            type_filter: "topic",
            search_type: :full_page,
            page:,
            blurb_length: 300,
          )
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.invalid_search_query") if results.blank?

        posts = results.posts
        ActiveRecord::Associations::Preloader.new(
          records: posts,
          associations: [:post_search_data, { user: :primary_group }, { topic: %i[category tags] }],
        ).call
        topics = posts.map(&:topic).compact.uniq(&:id)
        visible_tag_ids = ToolHelpers.visible_tag_ids(topics, guardian)

        ToolHelpers.text_and_structured(
          posts:
            posts.map do |post|
              ToolHelpers.evidence_post_json(post, excerpt: results.blurb(post, scope: guardian))
            end,
          topics: topics.map { |topic| search_topic_json(topic, visible_tag_ids) },
          users: users_json(posts),
          categories: categories_json(topics),
          groups: [],
          tags:
            topics
              .flat_map do |topic|
                topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name)
              end
              .uniq,
          meta: {
            page:,
            returned: posts.length,
            has_more: results.more_full_page_results == true,
            exhaustive: false,
            term: results.term || query,
          },
        )
      end

      def self.search_topic_json(topic, visible_tag_ids)
        {
          id: topic.id,
          slug: topic.slug,
          title: topic.title,
          category_id: topic.category_id,
          posts_count: topic.posts_count,
          reply_count: topic.reply_count,
          views: topic.views,
          like_count: topic.like_count,
          created_at: topic.created_at.iso8601,
          last_posted_at: topic.last_posted_at&.iso8601,
          closed: topic.closed,
          archived: topic.archived,
          tags: topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name),
        }
      end
      private_class_method :search_topic_json

      def self.users_json(posts)
        posts
          .filter_map(&:user)
          .uniq(&:id)
          .map do |user|
            {
              id: user.id,
              username: user.username,
              name: SiteSetting.enable_names? ? user.name : nil,
              avatar_template: user.avatar_template,
              primary_group_name: user.primary_group&.name,
            }
          end
      end
      private_class_method :users_json

      def self.categories_json(topics)
        topics
          .filter_map(&:category)
          .uniq(&:id)
          .map { |category| { id: category.id, name: category.name, slug: category.slug } }
      end
      private_class_method :categories_json
    end
  end
end
