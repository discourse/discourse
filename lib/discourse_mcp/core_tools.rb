# frozen_string_literal: true

require "base64"
require "directory_items_query"
require "tempfile"

module DiscourseMcp
  module ToolHelpers
    MAX_READ_LENGTH = 50_000

    module_function

    def text_and_structured(value)
      {
        content: [{ type: "text", text: JSON.generate(value) }],
        structuredContent: value,
        isError: false,
      }
    end

    def post_json(post)
      {
        id: post.id,
        topic_id: post.topic_id,
        post_number: post.post_number,
        username: post.username,
        raw: post.raw,
        created_at: post.created_at.iso8601,
        updated_at: post.updated_at.iso8601,
        url: post.full_url,
      }
    end

    def topic_json(topic, guardian, visible_tag_ids: nil)
      visible_tag_ids ||= self.visible_tag_ids([topic], guardian)

      {
        id: topic.id,
        title: topic.title,
        slug: topic.slug,
        category_id: topic.category_id,
        tags: topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name),
        posts_count: topic.posts_count,
        created_at: topic.created_at.iso8601,
        last_posted_at: topic.last_posted_at&.iso8601,
        closed: topic.closed,
        archived: topic.archived,
        url: topic.url,
      }
    end

    def discovery_topic_json(topic, visible_tag_ids)
      posters = topic.posters || topic.posters_summary
      latest_poster = posters.find { |poster| poster.extras.to_s.split.include?("latest") }

      {
        id: topic.id,
        slug: topic.slug,
        title: topic.title,
        category_id: topic.category_id,
        tags: topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name),
        created_at: topic.created_at.iso8601,
        last_posted_at: topic.last_posted_at&.iso8601,
        bumped_at: topic.bumped_at&.iso8601,
        posts_count: topic.posts_count,
        reply_count: topic.reply_count,
        views: topic.views,
        like_count: topic.like_count,
        posters_count: topic.participant_count,
        closed: topic.closed,
        archived: topic.archived,
        pinned: PinnedCheck.pinned?(topic, topic.user_data),
        visible: topic.visible,
        last_poster_username: latest_poster&.user&.username,
        posters:
          posters.map do |poster|
            {
              user_id: poster.user&.id,
              username: poster.user&.username,
              description: poster.description,
            }
          end,
      }
    end

    def evidence_post_json(post, excerpt: nil, include_raw: false)
      user = post.user
      topic = post.topic
      result = {
        id: post.id,
        topic_id: post.topic_id,
        post_number: post.post_number,
        post_type: post.post_type,
        username: user&.username,
        user_id: post.user_id,
        name: SiteSetting.enable_names? ? user&.name : nil,
        created_at: post.created_at.iso8601,
        updated_at: post.updated_at.iso8601,
        excerpt: excerpt,
        reply_to_post_number: post.reply_to_post_number,
        reply_count: post.reply_count,
        like_count: post.like_count,
        category_id: topic&.category_id,
        topic_slug: topic&.slug,
        topic_title: topic&.title,
        staff: user&.staff?,
        moderator: user&.moderator?,
        admin: user&.admin?,
        hidden: post.hidden,
        deleted_at: post.deleted_at&.iso8601,
      }

      if include_raw
        result[:raw] = post.raw.to_s.first(MAX_READ_LENGTH)
        result[:truncated] = post.raw.to_s.length > MAX_READ_LENGTH
      end

      %i[accepted_answer topic_accepted_answer].each do |field|
        result[field] = post.public_send(field) if post.respond_to?(field)
      end
      result
    end

    def visible_tag_ids(topics, guardian)
      DiscourseTagging.visible_tag_ids(topics.flat_map(&:tags), guardian)
    end

    def post_excerpt(post, guardian)
      cooked = ContentLocalization.translated_post_cooked(post, guardian)
      cooked ? Post.excerpt(cooked, nil, post:) : post.excerpt
    end

    def visible_user!(username, guardian)
      user = User.find_by_username(username)
      if user.blank? || !guardian.can_see_profile?(user)
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.user_not_found")
      end

      user
    end

    def visible_post!(post_id, guardian)
      post = Post.with_deleted.find_by(id: post_id)
      topic = Topic.with_deleted.find_by(id: post&.topic_id)
      post.association(:topic).target = topic if post && topic

      if post.blank? || topic.blank? || !guardian.can_see?(topic) || !guardian.can_see?(post)
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.post_not_found")
      end

      post
    end

    def ensure_current_author!(arguments, user)
      requested_author = arguments["author_username"]
      return if requested_author.blank? || requested_author.casecmp?(user.username)

      raise Discourse::InvalidAccess
    end

    def user_post_json(action)
      {
        id: action.post_id || action.id,
        topic_id: action.topic_id,
        post_number: action.post_number,
        slug: Slug.for(action.title),
        title: action.title,
        created_at: action.created_at&.iso8601,
        excerpt:
          (
            if action.cooked.present?
              PrettyText.excerpt(action.cooked, 300, keep_emoji_images: true)
            else
              nil
            end
          ),
        category_id: action.category_id,
      }
    end
  end

  module Tools
    class CurrentUser
      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        ToolHelpers.text_and_structured(
          id: user.id,
          username: user.username,
          name: user.name,
          trust_level: user.trust_level,
          admin: user.admin,
          moderator: user.moderator,
          scopes: request_context.scopes.to_a.sort,
          resource: DiscourseMcp.resource_url,
        )
      end
    end

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

    class ListDirectoryItems
      PAGE_SIZE = ::DirectoryItemsQuery::PAGE_SIZE
      PAGE_LIMIT = ::DirectoryItemsQuery::PAGE_LIMIT

      def self.call(arguments:, request_context:)
        unless SiteSetting.enable_user_directory?
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.user_directory_disabled")
        end

        period = arguments.fetch("period")
        period_type = DirectoryItem.period_types[period.to_sym]
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.invalid_directory_period") if !period_type

        page = arguments.fetch("page", 0)
        limit = arguments.fetch("limit", DirectoryItemsQuery::PAGE_SIZE)
        begin
          query_result =
            ::DirectoryItemsQuery.new(
              user: request_context.user,
              guardian: request_context.guardian,
            ).call(
              period_type:,
              group_name: arguments["group"],
              exclude_group_names: arguments["exclude_groups"],
              exclude_usernames: arguments["exclude_usernames"],
              order: arguments["order"],
              ascending: arguments.fetch("ascending", false),
              name: arguments["name"],
              username: arguments["username"],
              page:,
              limit:,
            )
        rescue ::DirectoryItemsQuery::GroupNotFound, Discourse::InvalidAccess
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.group_not_found")
        end
        rows =
          query_result.items.map do |item|
            item_json(item, period_type, query_result.active_column_names)
          end
        has_more = (page + 1) * limit < query_result.total

        ToolHelpers.text_and_structured(
          directory_items: rows,
          meta: {
            page:,
            limit:,
            returned: rows.length,
            total: query_result.total,
            has_more:,
            next_page: has_more ? page + 1 : nil,
            last_updated_at: query_result.last_updated_at&.iso8601,
          },
        )
      end

      def self.item_json(item, period_type, active_attributes)
        user = item.user
        result = {
          id: user.id,
          user: {
            id: user.id,
            username: user.username,
            name: SiteSetting.enable_names? ? user.name : nil,
            avatar_template: user.avatar_template,
            primary_group_name: user.primary_group&.name,
          },
          time_read:
            period_type == DirectoryItem.period_types[:all] ? item.user_stat&.time_read : nil,
        }
        DirectoryColumn.automatic_column_names.each do |attribute|
          result[attribute] = (
            if active_attributes.include?(attribute)
              item.public_send(attribute)
            else
              nil
            end
          )
        end
        result
      end
      private_class_method :item_json
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

    class GetUser
      def self.call(arguments:, request_context:)
        user = ToolHelpers.visible_user!(arguments.fetch("username"), request_context.guardian)

        details = {
          id: user.id,
          username: user.username,
          name: SiteSetting.enable_names? ? user.name : nil,
          trust_level: user.trust_level,
          created_at: user.created_at.iso8601,
          bio: user.user_profile.bio_raw.to_s.first(500),
          admin: user.admin,
          moderator: user.moderator,
        }
        ToolHelpers.text_and_structured(details)
      end
    end

    class ListUserPosts
      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        user = ToolHelpers.visible_user!(arguments.fetch("username"), guardian)
        unless guardian.can_see_user_actions?(user, [UserAction::NEW_TOPIC, UserAction::REPLY])
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.user_not_found")
        end

        page = arguments.fetch("page", 0)
        limit = arguments.fetch("limit", 30)
        actions =
          UserAction.stream(
            user_id: user.id,
            user:,
            offset: page * limit,
            limit: limit + 1,
            action_types: [UserAction::NEW_TOPIC, UserAction::REPLY],
            guardian:,
            ignore_private_messages: true,
          ).to_a
        has_more = actions.length > limit
        posts = actions.first(limit).map { |action| ToolHelpers.user_post_json(action) }

        ToolHelpers.text_and_structured(posts:, meta: { page:, limit:, has_more: })
      end
    end

    class GetUserSummary
      METRICS = %i[
        likes_given
        likes_received
        topics_entered
        posts_read_count
        days_visited
        topic_count
        post_count
        time_read
        recent_time_read
        bookmark_count
        can_see_summary_stats
        can_see_user_actions
      ].freeze

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        user = ToolHelpers.visible_user!(arguments.fetch("username"), guardian)
        summary =
          UserSummarySerializer.new(UserSummary.new(user, guardian), scope: guardian, root: false)
        serialized = summary.as_json.deep_symbolize_keys
        result = { username: user.username }
        METRICS.each { |metric| result[metric] = serialized[metric] }
        result[:top_topics] = serialized[:topics] || []
        result[:top_replies] = serialized[:replies] || []
        result[:top_links] = serialized[:links] || []
        result[:most_liked_by_users] = serialized[:most_liked_by_users] || []
        result[:most_liked_users] = serialized[:most_liked_users] || []
        result[:most_replied_to_users] = serialized[:most_replied_to_users] || []
        result[:top_categories] = serialized[:top_categories] || []
        result[:badges] = serialized[:badges] || []
        ToolHelpers.text_and_structured(result)
      end
    end

    class ListUserActions
      ACTION_TYPES = {
        "likes" => 1,
        "was_liked" => 2,
        "topics" => 4,
        "replies" => 5,
        "responses" => 6,
        "mentions" => 7,
        "quotes" => 9,
        "edits" => 11,
        "private_messages_sent" => 12,
        "private_messages_received" => 13,
        "solved" => 15,
        "assigned" => 16,
        "linked" => 17,
      }.freeze
      ACTION_NAMES = ACTION_TYPES.invert.freeze

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        user = ToolHelpers.visible_user!(arguments.fetch("username"), guardian)
        requested_types = Array(arguments["action_types"]).map { |name| ACTION_TYPES.fetch(name) }
        if !guardian.can_see_user_actions?(user, requested_types)
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.user_not_found")
        end

        action_types = requested_types
        if action_types.empty? && !guardian.can_see_user_actions?(user, UserAction.private_types)
          action_types = UserAction.types.values - UserAction.private_types
        end

        offset = arguments.fetch("offset", 0)
        limit = arguments.fetch("limit", 30)
        actions =
          UserAction.stream(
            user_id: user.id,
            user:,
            offset:,
            limit: limit + 1,
            action_types:,
            guardian:,
            ignore_private_messages: arguments["action_types"].blank?,
            acting_username: arguments["acting_username"],
          ).to_a
        has_more = actions.length > limit
        rows = actions.first(limit).map { |action| action_json(action) }
        categories = categories_json(actions.first(limit), guardian)

        ToolHelpers.text_and_structured(
          actions: rows,
          categories:,
          meta: {
            offset:,
            limit:,
            returned: rows.length,
            has_more:,
            next_offset: has_more ? offset + rows.length : nil,
          },
        )
      end

      def self.action_json(action)
        ToolHelpers.user_post_json(action).merge(
          action_type: ACTION_NAMES.fetch(action.action_type, "unknown"),
          action_type_id: action.action_type,
          id: action.id,
          post_id: action.post_id,
          username: action.username,
          acting_username: action.acting_username,
          target_username: action.target_username,
        )
      end
      private_class_method :action_json

      def self.categories_json(actions, guardian)
        category_ids = actions.filter_map(&:category_id).uniq
        return [] if category_ids.empty?

        Category
          .secured(guardian)
          .with_parents(category_ids)
          .map do |category|
            {
              id: category.id,
              name: category.name,
              slug: category.slug,
              parent_category_id: category.parent_category_id,
            }
          end
      end
      private_class_method :categories_json
    end

    class ListBookmarks
      def self.call(arguments:, request_context:)
        bookmarks =
          Bookmark
            .where(user_id: request_context.user_id)
            .includes(:bookmarkable)
            .order(updated_at: :desc)
            .limit(arguments.fetch("limit", 50).to_i.clamp(1, 100))
        values =
          bookmarks.filter_map do |bookmark|
            bookmarkable = bookmark.bookmarkable
            next if bookmarkable.blank? || !request_context.guardian.can_see?(bookmarkable)
            {
              id: bookmark.id,
              name: bookmark.name,
              reminder_at: bookmark.reminder_at&.iso8601,
              bookmarkable_type: bookmark.bookmarkable_type,
              bookmarkable_id: bookmark.bookmarkable_id,
            }
          end
        ToolHelpers.text_and_structured(bookmarks: values)
      end
    end

    class ListNotifications
      def self.call(arguments:, request_context:)
        limit = arguments.fetch("limit", 50).to_i.clamp(1, 100)
        notifications =
          Notification
            .where(user_id: request_context.user_id)
            .visible
            .includes(:topic)
            .order(id: :desc)
            .limit(limit)
        notifications =
          Notification.filter_inaccessible_topic_notifications(
            request_context.guardian,
            notifications,
          )
        notifications = Notification.filter_disabled_badge_notifications(notifications)
        notifications = Notification.populate_acting_user(notifications)
        serialized =
          notifications.map do |notification|
            NotificationSerializer.new(
              notification,
              scope: request_context.guardian,
              root: false,
            ).as_json
          end
        ToolHelpers.text_and_structured(notifications: serialized)
      end
    end

    class CreateTopic
      def self.call(arguments:, request_context:)
        ToolHelpers.ensure_current_author!(arguments, request_context.user)
        post =
          PostCreator.create!(
            request_context.user,
            title: arguments.fetch("title"),
            raw: arguments.fetch("raw"),
            category: arguments["category_id"],
            tags: Array(arguments["tags"]),
            skip_validations: false,
          )
        requested_author = arguments["author_username"]
        ToolHelpers.text_and_structured(
          id: post.id,
          topic_id: post.topic_id,
          slug: post.topic.slug,
          title: post.topic.title,
          username: post.user.username,
          requested_author:,
          author_applied:
            requested_author.present? ? post.user.username.casecmp?(requested_author) : nil,
        )
      end
    end

    class ReplyTopic
      def self.call(arguments:, request_context:)
        ToolHelpers.ensure_current_author!(arguments, request_context.user)
        post =
          PostCreator.create!(
            request_context.user,
            topic_id: arguments.fetch("topic_id"),
            raw: arguments.fetch("raw"),
            reply_to_post_number: arguments["reply_to_post_number"],
          )
        requested_author = arguments["author_username"]
        ToolHelpers.text_and_structured(
          id: post.id,
          topic_id: post.topic_id,
          post_number: post.post_number,
          username: post.user.username,
          requested_author:,
          author_applied:
            requested_author.present? ? post.user.username.casecmp?(requested_author) : nil,
        )
      end
    end

    class EditPost
      def self.call(arguments:, request_context:)
        post = Post.find_by(id: arguments.fetch("post_id").to_i)
        if post.blank? || !request_context.guardian.can_edit_post?(post)
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.post_not_found")
        end

        fields = { raw: arguments.fetch("raw") }
        fields[:edit_reason] = arguments["edit_reason"] if arguments["edit_reason"].present?
        success = PostRevisor.new(post, post.topic).revise!(request_context.user, fields)
        raise ToolError, post.errors.full_messages.join(", ") if !success
        post.reload
        ToolHelpers.text_and_structured(
          id: post.id,
          topic_id: post.topic_id,
          post_number: post.post_number,
          raw: post.raw,
          updated_at: post.updated_at.iso8601,
          edit_reason: post.edit_reason,
        )
      end
    end

    class UpdateTopic
      MUTABLE_FIELDS = %w[title category_id tags featured_link].freeze

      def self.call(arguments:, request_context:)
        topic = Topic.find_by(id: arguments.fetch("topic_id"))
        raise ToolError, I18n.t("mcp.errors.topic_not_found") if topic.blank?

        guardian = request_context.guardian
        guardian.ensure_can_edit!(topic)
        verify_original_values!(topic, arguments, guardian)
        changes = requested_changes(topic, arguments, guardian)
        shared_draft = topic.shared_draft
        destination_category_id = changes.delete("category_id") if shared_draft
        updated_fields = changes.keys
        updated_fields << "category_id" if destination_category_id
        raise ToolError, I18n.t("mcp.errors.topic_update_required") if updated_fields.empty?

        Topic.transaction do
          shared_draft.update!(category_id: destination_category_id) if destination_category_id

          if changes.present?
            category_changed = changes.key?("category_id")
            success =
              PostRevisor.new(topic.first_post, topic).revise!(
                request_context.user,
                changes.symbolize_keys,
                validate_post: false,
              )
            if !success
              raise ToolError,
                    TopicCategoryChangeValidator.safe_revision_errors(
                      topic:,
                      guardian:,
                      category_changed:,
                    ).join(", ")
            end
          end
        end

        topic.reload
        visible_tag_ids = ToolHelpers.visible_tag_ids([topic], guardian)
        ToolHelpers.text_and_structured(
          success: true,
          topic_id: topic.id,
          updated_fields:,
          topic: {
            id: topic.id,
            title: topic.title,
            slug: topic.slug,
            category_id: topic.category_id,
            destination_category_id: topic.shared_draft&.category_id,
            tags: topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name),
            featured_link: topic.featured_link,
          },
        )
      end

      def self.verify_original_values!(topic, arguments, guardian)
        if arguments.key?("original_title") && arguments["original_title"] != topic.title
          raise ToolError, I18n.t("edit_conflict")
        end
        visible_tag_ids = ToolHelpers.visible_tag_ids([topic], guardian)
        visible_tag_names =
          topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name).sort
        if arguments.key?("original_tags") && arguments["original_tags"].sort != visible_tag_names
          raise ToolError, I18n.t("edit_conflict")
        end
      end
      private_class_method :verify_original_values!

      def self.requested_changes(topic, arguments, guardian)
        changes = arguments.slice(*MUTABLE_FIELDS)
        changes.delete("title") if changes["title"] == topic.title
        current_category_id = topic.shared_draft&.category_id || topic.category_id
        changes.delete("category_id") if changes["category_id"].to_i == current_category_id.to_i
        if changes.key?("tags") && PostRevisor.tag_change_noop?(topic, changes["tags"])
          changes.delete("tags")
        end
        changes.delete("featured_link") if changes["featured_link"] == topic.featured_link

        if changes.key?("category_id")
          category_validation =
            TopicCategoryChangeValidator.call(
              topic:,
              category_id: changes["category_id"],
              guardian:,
              tag_names: changes.fetch("tags", topic.tags.map(&:name)),
              tags_changed: changes.key?("tags"),
            )
          if !category_validation.success?
            raise Discourse::InvalidAccess if category_validation.status == :forbidden

            raise ToolError, category_validation.error
          end
        end
        changes
      end
      private_class_method :requested_changes
    end

    class UpdateUser
      PROFILE_FIELDS = %w[
        name
        bio_raw
        location
        website
        title
        date_of_birth
        locale
        profile_background_upload_url
        card_background_upload_url
      ].freeze

      def self.call(arguments:, request_context:)
        user = User.find_by_username(arguments.fetch("username"))
        raise Discourse::InvalidAccess if user.blank? || user.id != request_context.user_id

        attributes = arguments.slice(*PROFILE_FIELDS).symbolize_keys
        upload = avatar_upload(arguments["upload_id"], user, request_context.guardian)
        if attributes.empty? && upload.blank?
          raise ToolError, I18n.t("mcp.errors.user_update_required")
        end
        validate_background_uploads!(attributes, user)

        User.transaction do
          updated = UserUpdater.new(request_context.user, user).update(attributes)
          raise ToolError, user.errors.full_messages.join(", ") if !updated
          update_avatar!(user, upload) if upload
        end

        user.reload
        ToolHelpers.text_and_structured(
          success: true,
          username: user.username,
          updated_fields: attributes.keys.map(&:to_s) + (upload ? ["upload_id"] : []),
          avatar_updated: upload.present?,
          user: {
            id: user.id,
            username: user.username,
            name: user.name,
            bio_raw: user.user_profile.bio_raw,
            location: user.user_profile.location,
            website: user.user_profile.website,
            title: user.title,
            date_of_birth: user.date_of_birth&.iso8601,
            locale: user.locale,
          },
        )
      end

      def self.avatar_upload(upload_id, user, guardian)
        return if upload_id.blank?
        if SiteSetting.discourse_connect_overrides_avatar || SiteSetting.auth_overrides_avatar ||
             !user.in_any_groups?(SiteSetting.uploaded_avatars_allowed_groups_map)
          raise Discourse::InvalidAccess
        end

        upload = Upload.find_by(id: upload_id, user_id: user.id)
        raise ToolError, I18n.t("mcp.errors.upload_not_found") if upload.blank?

        guardian.ensure_can_pick_avatar!(user.user_avatar || user.build_user_avatar, upload)
        upload
      end
      private_class_method :avatar_upload

      def self.validate_background_uploads!(attributes, user)
        %i[profile_background_upload_url card_background_upload_url].each do |field|
          next if !attributes.key?(field) || attributes[field].blank?

          upload = Upload.get_from_url(attributes[field])
          if upload.blank? || upload.user_id != user.id
            raise ToolError, I18n.t("mcp.errors.upload_not_found")
          end
        end
      end
      private_class_method :validate_background_uploads!

      def self.update_avatar!(user, upload)
        (user.user_avatar || user.build_user_avatar).update!(custom_upload_id: upload.id)
        user.update!(uploaded_avatar_id: upload.id)
      end
      private_class_method :update_avatar!
    end

    class UploadFile
      UPLOAD_TYPES = %w[avatar profile_background card_background composer].freeze

      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        if UPLOAD_TYPES.exclude?(arguments.fetch("upload_type"))
          raise ToolError, I18n.t("mcp.errors.invalid_upload_type")
        end
        if arguments["user_id"].present? && arguments["user_id"] != user.id
          raise Discourse::InvalidAccess
        end
        validate_source!(arguments)
        validate_avatar!(arguments.fetch("upload_type"), user)

        RateLimiter.new(
          user,
          "uploads-per-minute",
          SiteSetting.max_uploads_per_minute,
          1.minute,
        ).performed!
        file = uploaded_file(arguments)
        upload =
          UploadsController.create_upload(
            current_user: user,
            file:,
            url: arguments["url"],
            type: arguments.fetch("upload_type"),
            for_private_message: false,
            for_site_setting: false,
            pasted: false,
            is_api: true,
            retain_hours: 0,
          )
        if !upload.is_a?(Upload)
          raise ToolError, Array(upload[:errors] || upload["errors"]).join(", ")
        end

        serialized = UploadsController.serialize_upload(upload).deep_symbolize_keys
        ToolHelpers.text_and_structured(
          serialized.slice(
            :id,
            :url,
            :short_url,
            :short_path,
            :original_filename,
            :extension,
            :width,
            :height,
            :filesize,
            :human_filesize,
          ),
        )
      end

      def self.validate_source!(arguments)
        sources = [arguments["image_data"].present?, arguments["url"].present?].count(true)
        if sources != 1 || (arguments["image_data"].present? && arguments["filename"].blank?)
          raise ToolError, I18n.t("mcp.errors.invalid_upload_source")
        end
        return if arguments["url"].blank?

        uri = URI.parse(arguments["url"])
        unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.blank?
          raise ToolError, I18n.t("mcp.errors.invalid_upload_url")
        end
      rescue URI::InvalidURIError
        raise ToolError, I18n.t("mcp.errors.invalid_upload_url")
      end
      private_class_method :validate_source!

      def self.validate_avatar!(upload_type, user)
        return if upload_type != "avatar"
        if SiteSetting.discourse_connect_overrides_avatar || SiteSetting.auth_overrides_avatar ||
             !user.in_any_groups?(SiteSetting.uploaded_avatars_allowed_groups_map)
          raise Discourse::InvalidAccess
        end
      end
      private_class_method :validate_avatar!

      def self.uploaded_file(arguments)
        return if arguments["image_data"].blank?

        maximum_size = [
          SiteSetting.max_image_size_kb,
          SiteSetting.max_attachment_size_kb,
        ].max.kilobytes
        encoded = arguments.fetch("image_data")
        if encoded.bytesize > ((maximum_size * 4) / 3) + 4
          raise ToolError, I18n.t("mcp.errors.upload_too_large")
        end
        decoded = Base64.strict_decode64(encoded)
        raise ToolError, I18n.t("mcp.errors.upload_too_large") if decoded.bytesize > maximum_size

        tempfile = Tempfile.new("discourse-mcp-upload")
        tempfile.binmode
        tempfile.write(decoded)
        tempfile.rewind
        ActionDispatch::Http::UploadedFile.new(tempfile:, filename: arguments.fetch("filename"))
      rescue ArgumentError
        raise ToolError, I18n.t("mcp.errors.invalid_upload_data")
      end
      private_class_method :uploaded_file
    end

    class ListPrivateMessages
      MAILBOXES = %w[inbox sent archive unread new].freeze

      def self.call(arguments:, request_context:)
        mailbox = arguments.fetch("mailbox", "inbox")
        page = arguments.fetch("page", 0)
        per_page = arguments.fetch("per_page", 30)
        target = User.find_by_username(arguments["username"] || request_context.user.username)
        guardian = request_context.guardian
        if target.blank? || !guardian.can_see_private_messages?(target.id) ||
             (%w[unread new].include?(mailbox) && target.id != request_context.user_id)
          raise Discourse::InvalidAccess
        end

        group = group_for(arguments["group_name"], mailbox, guardian)
        list = message_list(target, mailbox, group, page, per_page, guardian)
        topics = list.topics
        lookahead_page = (page + 1) * per_page
        has_more = message_list(target, mailbox, group, lookahead_page, 1, guardian).topics.present?
        preload_participants(topics, target)
        archive_state = archive_state(topics, target)
        topic_users =
          TopicUser.where(user_id: target.id, topic_id: topics.map(&:id)).index_by(&:topic_id)

        ToolHelpers.text_and_structured(
          mailbox:,
          username: target.username,
          group_name: group&.name,
          messages:
            topics.map do |topic|
              message_json(
                topic,
                target,
                guardian,
                topic_users[topic.id],
                archive_state.fetch(topic.id, false),
              )
            end,
          meta: {
            page:,
            per_page:,
            has_more:,
          },
        )
      end

      def self.group_for(group_name, mailbox, guardian)
        return if group_name.blank?
        raise ToolError, I18n.t("mcp.errors.group_mailbox_sent") if mailbox == "sent"

        group = Group.find_by("LOWER(name) = ?", group_name.downcase)
        raise ToolError, I18n.t("mcp.errors.group_not_found") if group.blank?
        raise Discourse::InvalidAccess if !guardian.can_see_group_messages?(group)
        group
      end
      private_class_method :group_for

      def self.message_list(target, mailbox, group, page, per_page, guardian)
        query = TopicQuery.new(target, page:, per_page:, group_name: group&.name, guardian:)
        method_name = "list_private_messages"
        method_name += "_group" if group
        method_name += "_#{mailbox}" if mailbox != "inbox"
        query.public_send(method_name, target)
      end
      private_class_method :message_list

      def self.preload_participants(topics, target)
        user_ids = topics.flat_map(&:allowed_user_ids)
        user_lookup = UserLookup.new(user_ids)
        topics.each do |topic|
          topic.participants = topic.participants_summary(user: target, user_lookup:)
        end
      end
      private_class_method :preload_participants

      def self.archive_state(topics, target)
        topic_ids = topics.map(&:id)
        user_archived_ids =
          UserArchivedMessage.where(user_id: target.id, topic_id: topic_ids).pluck(:topic_id).to_set
        group_ids = topics.flat_map(&:allowed_group_ids).uniq
        member_group_ids = GroupUser.where(user_id: target.id, group_id: group_ids).pluck(:group_id)
        archived_pairs =
          GroupArchivedMessage
            .where(topic_id: topic_ids, group_id: member_group_ids)
            .pluck(:topic_id, :group_id)
            .to_set

        topics.to_h do |topic|
          topic_group_ids = topic.allowed_group_ids & member_group_ids
          all_groups_archived =
            topic_group_ids.present? &&
              topic_group_ids.all? { |group_id| archived_pairs.include?([topic.id, group_id]) }
          [topic.id, user_archived_ids.include?(topic.id) || all_groups_archived]
        end
      end
      private_class_method :archive_state

      def self.message_json(topic, target, guardian, topic_user, message_archived)
        seen =
          topic_user&.last_read_post_number.present? || topic.dismissed ||
            topic.created_at < target.user_option.treat_as_new_topic_start_date
        {
          topic_id: topic.id,
          slug: topic.slug,
          title: topic.title,
          posts_count: topic.posts_count,
          reply_count: topic.reply_count,
          created_at: topic.created_at.iso8601,
          last_posted_at: topic.last_posted_at&.iso8601,
          bumped_at: topic.bumped_at&.iso8601,
          last_read_post_number: topic_user&.last_read_post_number,
          unread_posts: topic_user ? Unread.new(topic, topic_user, guardian).unread_posts : 0,
          unseen: !seen,
          topic_archived: topic.archived,
          message_archived:,
          notification_level: topic_user&.notification_level,
          recent_participants:
            Array(topic.participants).map do |poster|
              {
                user_id: poster.user&.id,
                username: poster.user&.username,
                name: SiteSetting.enable_names? ? poster.user&.name : nil,
              }
            end,
        }
      end
      private_class_method :message_json
    end

    class ReadPrivateMessage
      def self.call(arguments:, request_context:)
        topic = private_message_topic!(arguments.fetch("topic_id"), request_context.guardian)
        start_post_number = arguments.fetch("start_post_number", 1)
        post_limit = arguments.fetch("post_limit", 5)
        posts =
          Post
            .secured(request_context.guardian)
            .where(topic_id: topic.id, post_number: start_post_number..)
            .order(:post_number)
            .includes(:topic, :user)
            .limit(post_limit + 1)
            .to_a
        has_more = posts.length > post_limit
        posts = posts.first(post_limit)
        topic_user = TopicUser.find_by(topic:, user: request_context.user)

        ToolHelpers.text_and_structured(
          topic_id: topic.id,
          slug: topic.slug,
          title: topic.title,
          archetype: topic.archetype,
          subtype: topic.subtype,
          posts_count: topic.posts_count,
          last_read_post_number: topic_user&.last_read_post_number,
          topic_archived: topic.archived,
          message_archived: topic.message_archived?(request_context.user),
          allowed_users: topic.allowed_users.map { |user| user_json(user) },
          allowed_groups: topic.allowed_groups.map { |group| group_json(group) },
          posts: posts.map { |post| ToolHelpers.evidence_post_json(post, include_raw: true) },
          meta: {
            start_post: start_post_number,
            returned: posts.length,
            has_more:,
          },
        )
      end

      def self.private_message_topic!(topic_id, guardian)
        topic = Topic.includes(:allowed_users, :allowed_groups).find_by(id: topic_id)
        if topic.blank? || !topic.private_message? || !guardian.can_see?(topic)
          raise ToolError, I18n.t("mcp.errors.private_message_not_found")
        end
        topic
      end

      def self.user_json(user)
        { id: user.id, username: user.username, name: SiteSetting.enable_names? ? user.name : nil }
      end

      def self.group_json(group)
        { id: group.id, name: group.name, full_name: group.full_name }
      end
    end

    class CreatePrivateMessage
      def self.call(arguments:, request_context:)
        ToolHelpers.ensure_current_author!(arguments, request_context.user)
        usernames = Array(arguments["usernames"])
        group_names = Array(arguments["group_names"])
        emails = Array(arguments["email_addresses"])
        if usernames.empty? && group_names.empty? && emails.empty?
          raise ToolError, I18n.t("mcp.errors.private_message_recipient_required")
        end
        ensure_recipient_limit!(request_context.user, usernames, group_names, emails)

        options = {
          title: arguments.fetch("title"),
          raw: arguments.fetch("raw"),
          archetype: Archetype.private_message,
        }
        options[:target_usernames] = usernames.uniq.join(",") if usernames.present?
        options[:target_group_names] = group_names.uniq.join(",") if group_names.present?
        options[:target_emails] = emails.uniq.join(",") if emails.present?
        post = PostCreator.create!(request_context.user, options)
        ToolHelpers.text_and_structured(
          id: post.id,
          topic_id: post.topic_id,
          post_number: post.post_number,
          slug: post.topic.slug,
          title: post.topic.title,
        )
      end

      def self.ensure_recipient_limit!(user, usernames, group_names, emails)
        return if user.staff?

        recipient_count =
          [usernames, group_names, emails].sum do |recipients|
            recipients.uniq { |recipient| recipient.downcase }.length
          end
        return if recipient_count <= SiteSetting.max_allowed_message_recipients

        raise ToolError,
              I18n.t(
                :max_pm_recipients,
                recipients_limit: SiteSetting.max_allowed_message_recipients,
              )
      end
      private_class_method :ensure_recipient_limit!
    end

    class ReplyPrivateMessage
      def self.call(arguments:, request_context:)
        ToolHelpers.ensure_current_author!(arguments, request_context.user)
        topic =
          ReadPrivateMessage.private_message_topic!(
            arguments.fetch("topic_id"),
            request_context.guardian,
          )
        post =
          PostCreator.create!(
            request_context.user,
            topic_id: topic.id,
            raw: arguments.fetch("raw"),
            reply_to_post_number: arguments["reply_to_post_number"],
          )
        ToolHelpers.text_and_structured(
          id: post.id,
          topic_id: post.topic_id,
          post_number: post.post_number,
          reply_to_post_number: post.reply_to_post_number,
          slug: topic.slug,
        )
      end
    end

    class InviteToPrivateMessage
      def self.call(arguments:, request_context:)
        ToolHelpers.ensure_current_author!(arguments, request_context.user)
        topic =
          ReadPrivateMessage.private_message_topic!(
            arguments.fetch("topic_id"),
            request_context.guardian,
          )
        recipients = arguments.values_at("username", "group_name", "email_address").compact_blank
        if recipients.length != 1
          raise ToolError, I18n.t("mcp.errors.private_message_single_recipient")
        end
        if arguments.key?("notify_group_members") && arguments["group_name"].blank?
          raise ToolError, I18n.t("mcp.errors.private_message_group_notification")
        end
        if arguments["custom_message"].present? && arguments["email_address"].blank?
          raise ToolError, I18n.t("mcp.errors.private_message_email_message")
        end
        ensure_recipient_slot!(topic, request_context.guardian)

        if arguments["group_name"].present?
          invite_group!(topic, arguments, request_context)
        elsif arguments["username"].present?
          invite_user!(topic, arguments.fetch("username"), request_context)
        else
          invite_email!(topic, arguments, request_context)
        end
      end

      def self.invite_group!(topic, arguments, request_context)
        group = Group.find_by(name: arguments.fetch("group_name"))
        raise ToolError, I18n.t("mcp.errors.group_not_found") if group.blank?
        request_context.guardian.ensure_can_invite_group_to_private_message!(group, topic)

        notifications_requested = arguments.fetch("notify_group_members", true)
        topic.invite_group(request_context.user, group, should_notify: notifications_requested)
        ToolHelpers.text_and_structured(
          topic_id: topic.id,
          recipient_type: "group",
          status: "added",
          group: ReadPrivateMessage.group_json(group),
          notifications_requested:,
        )
      end
      private_class_method :invite_group!

      def self.ensure_recipient_slot!(topic, guardian)
        return if guardian.is_staff? || !topic.reached_recipients_limit?

        raise ToolError,
              I18n.t(
                "pm_reached_recipients_limit",
                recipients_limit: SiteSetting.max_allowed_message_recipients,
              )
      end
      private_class_method :ensure_recipient_slot!

      def self.invite_user!(topic, username, request_context)
        user = User.find_by_username(username)
        raise ToolError, I18n.t("mcp.errors.user_not_found") if user.blank?
        raise Discourse::InvalidAccess if !request_context.guardian.can_invite_to?(topic)

        added = topic.invite(request_context.user, user.username)
        raise ToolError, I18n.t("mcp.errors.private_message_invite_failed") if !added
        ToolHelpers.text_and_structured(
          topic_id: topic.id,
          recipient_type: "user",
          status: "added",
          user: ReadPrivateMessage.user_json(user),
        )
      end
      private_class_method :invite_user!

      def self.invite_email!(topic, arguments, request_context)
        raise Discourse::InvalidAccess if !request_context.guardian.can_invite_via_email?(topic)

        added =
          topic.invite(
            request_context.user,
            arguments.fetch("email_address"),
            nil,
            arguments["custom_message"],
          )
        raise ToolError, I18n.t("mcp.errors.private_message_invite_failed") if !added
        ToolHelpers.text_and_structured(
          topic_id: topic.id,
          recipient_type: "email",
          status: "submitted",
          participant_added: false,
          outcome_confirmed: false,
        )
      end
      private_class_method :invite_email!
    end

    class SetPostDeleted
      def self.call(arguments:, request_context:)
        post = Post.find_by(id: arguments.fetch("post_id").to_i, user_id: request_context.user_id)
        raise DiscourseMcp::ToolError, "Post not found" if post.blank?

        if arguments.fetch("deleted")
          raise Discourse::InvalidAccess if !request_context.guardian.can_delete_post?(post)
          PostDestroyer.new(request_context.user, post).destroy
        else
          raise Discourse::InvalidAccess if !request_context.guardian.can_recover_post?(post)
          PostDestroyer.new(request_context.user, post).recover
        end
        ToolHelpers.text_and_structured(post_id: post.id, deleted: arguments.fetch("deleted"))
      end
    end

    class GetDraft
      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        draft_key = arguments.fetch("draft_key")
        sequence =
          if arguments.key?("sequence")
            arguments.fetch("sequence")
          else
            DraftSequence.current(user, draft_key)
          end
        draft = Draft.get(user, draft_key, sequence)

        return ToolHelpers.text_and_structured(draft_key:, found: false) if draft.blank?

        parsed = JSON.parse(draft)
        parsed = {} if !parsed.is_a?(Hash)
        ToolHelpers.text_and_structured(
          draft_key:,
          sequence:,
          found: true,
          data: {
            title: parsed["title"],
            reply: parsed["reply"],
            category_id: parsed["categoryId"],
            tags: parsed["tags"].is_a?(Array) ? parsed["tags"] : [],
            action: parsed["action"],
          },
        )
      rescue Draft::OutOfSequence
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict")
      rescue JSON::ParserError
        ToolHelpers.text_and_structured(
          draft_key:,
          sequence:,
          found: true,
          data: {
            title: nil,
            reply: nil,
            category_id: nil,
            tags: [],
            action: nil,
          },
        )
      end
    end

    class SaveDraft
      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        draft_key = arguments.fetch("draft_key")

        if !Draft.exists?(user_id: user.id, draft_key:) &&
             Draft.where(user_id: user.id).count >= SiteSetting.max_drafts_per_user
          raise DiscourseMcp::ToolError, I18n.t("draft.too_many_drafts.title")
        end

        data = { reply: arguments.fetch("reply") }
        action = arguments["action"] || default_action(draft_key)
        data[:action] = action if action.present?
        data[:title] = arguments["title"] if arguments.key?("title")
        data[:categoryId] = arguments["category_id"] if arguments.key?("category_id")
        data[:tags] = arguments["tags"] if arguments["tags"].present?

        if (match = draft_key.match(/\Atopic_(\d+)\z/))
          data[:topic_id] = match[1].to_i
        end

        serialized_data = data.to_json
        if serialized_data.length > SiteSetting.max_draft_length
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_too_long")
        end

        sequence = Draft.set(user, draft_key, arguments.fetch("sequence", 0), serialized_data)
        ToolHelpers.text_and_structured(draft_key:, sequence:, saved: true)
      rescue Draft::OutOfSequence
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict")
      end

      def self.default_action(draft_key)
        return "createTopic" if draft_key == Draft::NEW_TOPIC
        return "privateMessage" if draft_key == Draft::NEW_PRIVATE_MESSAGE
        "reply" if draft_key.match?(/\Atopic_\d+\z/)
      end
      private_class_method :default_action
    end

    class DeleteDraft
      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        draft_key = arguments.fetch("draft_key")
        Draft.clear(user, draft_key, arguments.fetch("sequence"))
        ToolHelpers.text_and_structured(draft_key:, deleted: true)
      rescue Draft::OutOfSequence
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict")
      end
    end

    class SetUserStatus
      def self.call(arguments:, request_context:)
        user = request_context.user or raise Discourse::InvalidAccess
        if arguments.fetch("clear", false)
          user.clear_status!
        else
          user.set_status!(
            arguments.fetch("description"),
            arguments.fetch("emoji"),
            arguments["ends_at"],
          )
        end
        ToolHelpers.text_and_structured(success: true)
      end
    end
  end
end
