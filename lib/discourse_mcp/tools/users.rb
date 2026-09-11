# frozen_string_literal: true

require "directory_items_query"

module DiscourseMcp
  module Tools
    class CurrentUser
      OUTPUT_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER,
          username: OutputSchema::STRING,
          name: OutputSchema::STRING_OR_NULL,
          trust_level: OutputSchema::INTEGER,
          admin: OutputSchema::BOOLEAN,
          moderator: OutputSchema::BOOLEAN,
          scopes: OutputSchema::STRING_ARRAY,
          resource: OutputSchema::STRING,
        )

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

    class ListDirectoryItems
      PAGE_SIZE = ::DirectoryItemsQuery::PAGE_SIZE
      PAGE_LIMIT = ::DirectoryItemsQuery::PAGE_LIMIT
      OUTPUT_SCHEMA =
        OutputSchema.object(directory_items: OutputSchema::OBJECT_ARRAY, meta: OutputSchema::OBJECT)

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

    class GetUser
      OUTPUT_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER,
          username: OutputSchema::STRING,
          name: OutputSchema::STRING_OR_NULL,
          trust_level: OutputSchema::INTEGER,
          created_at: OutputSchema::STRING,
          bio: OutputSchema::STRING,
          admin: OutputSchema::BOOLEAN,
          moderator: OutputSchema::BOOLEAN,
        )

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
      OUTPUT_SCHEMA =
        OutputSchema.object(posts: OutputSchema::OBJECT_ARRAY, meta: OutputSchema::OBJECT)

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
      OUTPUT_SCHEMA =
        OutputSchema.object(
          username: OutputSchema::STRING,
          likes_given: OutputSchema::ANY,
          likes_received: OutputSchema::ANY,
          topics_entered: OutputSchema::ANY,
          posts_read_count: OutputSchema::ANY,
          days_visited: OutputSchema::ANY,
          topic_count: OutputSchema::ANY,
          post_count: OutputSchema::ANY,
          time_read: OutputSchema::ANY,
          recent_time_read: OutputSchema::ANY,
          bookmark_count: OutputSchema::ANY,
          can_see_summary_stats: OutputSchema::ANY,
          can_see_user_actions: OutputSchema::ANY,
          top_topics: OutputSchema::OBJECT_ARRAY,
          top_replies: OutputSchema::OBJECT_ARRAY,
          top_links: OutputSchema::OBJECT_ARRAY,
          most_liked_by_users: OutputSchema::OBJECT_ARRAY,
          most_liked_users: OutputSchema::OBJECT_ARRAY,
          most_replied_to_users: OutputSchema::OBJECT_ARRAY,
          top_categories: OutputSchema::OBJECT_ARRAY,
          badges: OutputSchema::OBJECT_ARRAY,
        )

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
      OUTPUT_SCHEMA =
        OutputSchema.object(
          actions: OutputSchema::OBJECT_ARRAY,
          categories: OutputSchema::OBJECT_ARRAY,
          meta: OutputSchema::OBJECT,
        )

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
      OUTPUT_SCHEMA =
        OutputSchema.object(
          success: OutputSchema::BOOLEAN,
          username: OutputSchema::STRING,
          updated_fields: OutputSchema::STRING_ARRAY,
          avatar_updated: OutputSchema::BOOLEAN,
          user: OutputSchema::OBJECT,
        )

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

    class SetUserStatus
      OUTPUT_SCHEMA = OutputSchema.object(success: OutputSchema::BOOLEAN)

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
