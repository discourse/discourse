# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class ReadTopicPosts
      SELECTION_KEYS = {
        "latest" => %w[limit replies_only],
        "earliest" => %w[limit replies_only],
        "post_ids" => %w[post_ids],
        "around_post" => %w[post_number limit],
        "usernames" => %w[usernames limit replies_only],
      }.freeze

      def self.call(arguments:, request_context:)
        validate_selection!(arguments)
        topic = Topic.with_deleted.find_by(id: arguments.fetch("topic_id"))
        guardian = request_context.guardian
        if topic.blank? || !guardian.can_see?(topic)
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.topic_not_found")
        end

        selection_mode = arguments.fetch("selection_mode")
        limit = arguments.fetch("limit", 20)
        stream_size = nil
        selected_ids = nil
        posts = nil

        if selection_mode == "post_ids"
          selected_ids = arguments.fetch("post_ids")
        elsif selection_mode == "around_post"
          posts = around_posts(topic, arguments.fetch("post_number"), limit, request_context.user)
        else
          stream_size, selected_ids = stream_selection(topic, arguments, request_context)
        end

        posts ||= posts_for_ids(topic, selected_ids, request_context.user, guardian)
        ToolHelpers.text_and_structured(
          topic_id: topic.id,
          selection_mode:,
          posts: posts.map { |post| ToolHelpers.evidence_post_json(post, include_raw: true) },
          meta: {
            visible_stream_size: stream_size,
            selected: selected_ids&.length || posts.length,
            returned: posts.length,
            max_requests: %w[post_ids around_post].include?(selection_mode) ? 1 : 2,
            exhaustive: false,
          },
        )
      end

      def self.validate_selection!(arguments)
        selection_mode = arguments["selection_mode"]
        allowed_keys = SELECTION_KEYS[selection_mode]
        supplied_keys = arguments.filter_map { |key, value| key unless value.nil? }
        supplied_selection_keys = supplied_keys - %w[topic_id selection_mode]
        required_key = "post_ids" if selection_mode == "post_ids"
        required_key = "post_number" if selection_mode == "around_post"
        required_key = "usernames" if selection_mode == "usernames"

        if allowed_keys.blank? ||
             supplied_selection_keys.any? { |key| allowed_keys.exclude?(key) } ||
             (required_key && arguments[required_key].blank?)
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.invalid_post_selection")
        end
      end
      private_class_method :validate_selection!

      def self.stream_selection(topic, arguments, request_context)
        options = { limit: 1, include_suggested: false, include_related: false }
        if arguments.fetch("selection_mode") == "usernames"
          options[:username_filters] = arguments.fetch("usernames")
        end
        topic_view = TopicView.new(topic, request_context.user, options)
        posts =
          request_context.guardian.filter_hidden_posts(
            topic_view.filtered_posts,
            category: topic.category,
          )
        stream_size = posts.count
        posts = posts.where("posts.post_number > 1") if arguments["replies_only"]
        limit = arguments.fetch("limit", 20)
        selected_ids =
          if arguments.fetch("selection_mode") == "latest"
            posts.reorder(sort_order: :desc).limit(limit).pluck(:id).reverse
          else
            posts.reorder(sort_order: :asc).limit(limit).pluck(:id)
          end
        [stream_size, selected_ids]
      end
      private_class_method :stream_selection

      def self.around_posts(topic, post_number, limit, user)
        topic_view =
          TopicView.new(
            topic,
            user,
            post_number:,
            limit:,
            include_suggested: false,
            include_related: false,
          )
        guardian = topic_view.guardian
        posts_visible_to_guardian(topic_view.posts, topic, guardian).first(limit)
      end
      private_class_method :around_posts

      def self.posts_for_ids(topic, post_ids, user, guardian)
        topic_view =
          TopicView.new(
            topic,
            user,
            post_ids:,
            limit: 50,
            include_suggested: false,
            include_related: false,
          )
        visible_posts = posts_visible_to_guardian(topic_view.posts, topic, guardian)
        posts = visible_posts.index_by(&:id)
        post_ids.filter_map { |post_id| posts[post_id] }
      end
      private_class_method :posts_for_ids

      def self.posts_visible_to_guardian(posts, topic, guardian)
        posts.select do |post|
          post.association(:topic).target = topic
          guardian.can_see?(post)
        end
      end
      private_class_method :posts_visible_to_guardian
    end

    class GetPostReplies
      DIRECT_REPLIES_LIMIT = 20
      MODES = %w[reply_ids direct_replies reply_history].freeze

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        post = ToolHelpers.visible_post!(arguments.fetch("post_id"), guardian)
        mode = arguments.fetch("mode", "reply_ids")
        if MODES.exclude?(mode)
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.invalid_reply_mode")
        end

        return reply_ids_result(post, guardian) if mode == "reply_ids"

        posts =
          if mode == "direct_replies"
            direct_replies(post, arguments["after_post_number"], request_context)
          else
            reply_history(post, request_context)
          end

        ToolHelpers.text_and_structured(
          post_id: post.id,
          mode:,
          posts: posts.map { |reply| ToolHelpers.evidence_post_json(reply, include_raw: true) },
          meta: {
            returned: posts.length,
            has_more: nil,
            page_was_full: mode == "direct_replies" ? posts.length == DIRECT_REPLIES_LIMIT : nil,
            upstream_limit:
              mode == "direct_replies" ? DIRECT_REPLIES_LIMIT : "site max_reply_history",
          },
        )
      end

      def self.reply_ids_result(post, guardian)
        replies = post.reply_ids(guardian)
        reply_posts = Post.with_deleted.where(id: replies.pluck(:id)).index_by(&:id)
        visible_replies =
          replies.select do |reply|
            reply_post = reply_posts[reply[:id]]
            next false if reply_post.blank?

            reply_post.association(:topic).target = post.topic
            guardian.can_see?(reply_post)
          end

        ToolHelpers.text_and_structured(
          post_id: post.id,
          mode: "reply_ids",
          replies: visible_replies,
          meta: {
            returned: visible_replies.length,
            exhaustive: false,
            upstream_bounded: "recursive descendants up to depth 1000",
          },
        )
      end
      private_class_method :reply_ids_result

      def self.direct_replies(post, after_post_number, request_context)
        after_post_number = [after_post_number.to_i, 1].max
        post_ids =
          post
            .replies
            .secured(request_context.guardian)
            .where(post_number: after_post_number + 1..)
            .order(:post_number)
            .limit(DIRECT_REPLIES_LIMIT)
            .pluck(:id)
        posts_for_ids(post.topic, post_ids, request_context)
      end
      private_class_method :direct_replies

      def self.reply_history(post, request_context)
        topic_view =
          TopicView.new(
            post.topic,
            request_context.user,
            include_suggested: false,
            include_related: false,
            reply_history_for: post.id,
          )
        topic_view.posts.select { |reply| request_context.guardian.can_see?(reply) }
      end
      private_class_method :reply_history

      def self.posts_for_ids(topic, post_ids, request_context)
        return [] if post_ids.empty?

        topic_view =
          TopicView.new(
            topic,
            request_context.user,
            post_ids:,
            include_related: false,
            include_suggested: false,
          )
        posts = topic_view.posts.index_by(&:id)
        post_ids.filter_map do |post_id|
          post = posts[post_id]
          post if request_context.guardian.can_see?(post)
        end
      end
      private_class_method :posts_for_ids
    end

    class ListLatestPosts
      def self.call(arguments:, request_context:)
        before_post_id = arguments["before_post_id"]
        posts =
          LatestPostsQuery
            .new(user: request_context.user, guardian: request_context.guardian)
            .public_posts(before_post_id:)
            .to_a
        rows =
          (
            if arguments.fetch("replies_only", false)
              posts.select { |post| post.post_number > 1 }
            else
              posts
            end
          )

        ToolHelpers.text_and_structured(
          posts:
            rows.map do |post|
              ToolHelpers.evidence_post_json(
                post,
                excerpt: ToolHelpers.post_excerpt(post, request_context.guardian),
                include_raw: true,
              )
            end,
          meta: {
            before_post_id:,
            upstream_page_size: LatestPostsQuery::PAGE_SIZE,
            upstream_returned: posts.length,
            returned: rows.length,
            has_more: nil,
            page_was_full: posts.length == LatestPostsQuery::PAGE_SIZE,
            next_before_post_id: posts.last&.id,
            replies_only_projection: arguments.fetch("replies_only", false),
            anonymous_cache_seconds: 60,
          },
        )
      end
    end

    class GetTopicViewStats
      def self.call(arguments:, request_context:)
        topic = Topic.find_by(id: arguments.fetch("topic_id"))
        if topic.blank? || !request_context.guardian.can_see?(topic)
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.topic_not_found")
        end

        from = arguments["from"] ? parse_date(arguments["from"]) : 30.days.ago.to_date
        to = arguments["to"] ? parse_date(arguments["to"]) : Date.current
        stats = TopicViewStatsQuery.call(topic:, guardian: request_context.guardian, from:, to:)
        rows =
          stats.map do |stat|
            {
              viewed_at: stat.viewed_at.iso8601,
              views: stat.anonymous_views + stat.logged_in_views,
            }
          end

        ToolHelpers.text_and_structured(
          topic_id: topic.id,
          view_stats: rows,
          meta: {
            from: arguments["from"],
            to: arguments["to"],
            default_range_days: arguments["from"] || arguments["to"] ? nil : 30,
            upstream_max_rows: TopicViewStatsQuery::MAX_STATS,
            returned: rows.length,
          },
        )
      end

      def self.parse_date(value)
        Date.iso8601(value)
      rescue Date::Error
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.invalid_date")
      end
      private_class_method :parse_date
    end

    class GetTopic
      def self.call(arguments:, request_context:)
        topic = Topic.find_by(id: arguments.fetch("topic_id").to_i)
        if topic.blank? || !request_context.guardian.can_see?(topic)
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.topic_not_found")
        end

        limit = arguments.fetch("post_limit", 5)
        start_post_number = arguments.fetch("start_post_number", 1)
        posts =
          Post
            .secured(request_context.guardian)
            .where(topic_id: topic.id)
            .where(post_number: start_post_number..)
            .order(:post_number)
            .limit(limit + 1)
            .includes(:topic, :user)
            .to_a
        has_more = posts.length > limit
        posts = posts.first(limit)
        visible_tag_ids = ToolHelpers.visible_tag_ids([topic], request_context.guardian)
        result =
          ToolHelpers.topic_json(topic, request_context.guardian, visible_tag_ids:).merge(
            posts: posts.map { |post| ToolHelpers.evidence_post_json(post, include_raw: true) },
            meta: {
              start_post: start_post_number,
              returned: posts.length,
              has_more:,
            },
          )
        ToolHelpers.text_and_structured(result)
      end
    end

    class GetPost
      def self.call(arguments:, request_context:)
        post = ToolHelpers.visible_post!(arguments.fetch("post_id"), request_context.guardian)
        result =
          ToolHelpers.evidence_post_json(post, include_raw: true).slice(
            :id,
            :topic_id,
            :topic_slug,
            :post_number,
            :username,
            :created_at,
            :raw,
            :truncated,
            :accepted_answer,
            :topic_accepted_answer,
          )
        ToolHelpers.text_and_structured(result)
      end
    end

    class ListTopics
      def self.call(arguments:, request_context:)
        limit = arguments.fetch("limit", 30).to_i.clamp(1, 50)
        topics = TopicQuery.new(request_context.user).list_latest.topics.first(limit)
        ActiveRecord::Associations::Preloader.new(records: topics, associations: :tags).call
        visible_tag_ids = ToolHelpers.visible_tag_ids(topics, request_context.guardian)
        ToolHelpers.text_and_structured(
          topics:
            topics.map do |topic|
              ToolHelpers.topic_json(topic, request_context.guardian, visible_tag_ids:)
            end,
        )
      end
    end

    class ListCategories
      def self.call(arguments:, request_context:)
        categories = Category.secured(request_context.guardian).order(:position, :id).limit(500)
        ToolHelpers.text_and_structured(
          categories:
            categories.map do |category|
              {
                id: category.id,
                name: category.name,
                slug: category.slug,
                parent_category_id: category.parent_category_id,
                topic_count: category.topic_count,
              }
            end,
        )
      end
    end

    class ListTags
      def self.call(arguments:, request_context:)
        column = Tag.topic_count_column(request_context.guardian)
        tags = Tag.order(column => :desc).limit(arguments.fetch("limit", 100).to_i.clamp(1, 200))
        visible = DiscourseTagging.filter_visible(tags, request_context.guardian)
        ToolHelpers.text_and_structured(
          tags:
            visible.map do |tag|
              { id: tag.id, name: tag.name, topic_count: tag.public_send(column) }
            end,
        )
      end
    end
  end
end
