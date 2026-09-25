# frozen_string_literal: true

require "group_directory_query"

module DiscourseMcp
  module Tools
    module GroupSupport
      MEMBERSHIP_NOT_LOADED = Object.new.freeze
      SAFE_DETAIL_FIELDS = %i[
        id
        automatic
        name
        display_name
        user_count
        mentionable_level
        messageable_level
        visibility_level
        primary_group
        title
        grant_trust_level
        has_messages
        flair_url
        flair_bg_color
        flair_color
        bio_raw
        bio_cooked
        bio_excerpt
        public_admission
        public_exit
        allow_membership_requests
        full_name
        default_notification_level
        membership_request_template
        is_group_user
        is_group_owner
        is_group_owner_display
        members_visibility_level
        can_see_members
        can_admin_group
        can_edit_group
        publish_read_state
        automatic_membership_email_domains
        watching_category_ids
        tracking_category_ids
        watching_first_post_category_ids
        regular_category_ids
        muted_category_ids
        watching_tags
        watching_first_post_tags
        tracking_tags
        regular_tags
        muted_tags
        mentionable
        messageable
        flair_icon
        flair_type
        message_count
        allow_unknown_sender_topic_replies
        associated_group_ids
      ].freeze

      module_function

      def find_visible!(arguments, guardian)
        id = arguments["id"]
        name = arguments["name"].to_s.strip.presence
        raise ToolError, I18n.t("mcp.errors.group_not_found") if id.present? == name.present?

        group =
          if id
            Group.visible_groups(guardian.user).find_by(id:)
          else
            Group.visible_groups(guardian.user).find_by("LOWER(groups.name) = ?", name.downcase)
          end
        group or raise ToolError, I18n.t("mcp.errors.group_not_found")
      end

      def group_json(
        group,
        guardian,
        membership: MEMBERSHIP_NOT_LOADED,
        can_see_members: MEMBERSHIP_NOT_LOADED
      )
        if membership.equal?(MEMBERSHIP_NOT_LOADED)
          membership = group.group_users.find_by(user: guardian.user) if guardian.authenticated?
        end
        if can_see_members.equal?(MEMBERSHIP_NOT_LOADED)
          can_see_members = guardian.can_see_group_members?(group)
        end

        can_admin_group = guardian.can_admin_group?(group)
        {
          id: group.id,
          name: group.name,
          full_name: group.full_name,
          title: group.title,
          automatic: group.automatic,
          user_count: can_see_members ? group.user_count : nil,
          visibility_level: group.visibility_level,
          members_visibility_level: group.members_visibility_level,
          mentionable_level: group.mentionable_level,
          messageable_level: group.messageable_level,
          public_admission: group.public_admission,
          public_exit: group.public_exit,
          allow_membership_requests: group.allow_membership_requests,
          bio_excerpt: group.bio_cooked.present? ? PrettyText.excerpt(group.bio_cooked, 200) : nil,
          is_group_user: membership.present?,
          is_group_owner: membership&.owner? || false,
          can_see_members:,
          can_edit_group: guardian.can_edit_group?(group, group_user: membership),
          can_admin_group:,
        }
      end

      def group_detail_json(group, guardian)
        GroupShowSerializer
          .new(group, scope: guardian, root: false)
          .as_json
          .slice(*SAFE_DETAIL_FIELDS)
      end

      def filter_users(users, filter, guardian)
        return users if filter.blank?

        filter = filter.split(",") if filter.include?(",")
        if guardian.is_admin?
          users.filter_by_username_or_email(filter)
        else
          users.filter_by_username(filter)
        end
      end
    end

    class ListGroups
      REQUIRED_SCOPES = [Scopes::GROUPS_READ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(groups: OutputSchema::OBJECT_ARRAY, meta: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        page = arguments.fetch("page", 0)
        limit = arguments.fetch("limit", 36)
        result =
          GroupDirectoryQuery.new(
            user: request_context.user,
            guardian:,
            modifier_context: request_context,
          ).call(
            username: arguments["username"],
            filter: arguments["filter"],
            type: arguments["type"],
            order: arguments["order"],
            ascending: arguments.fetch("ascending", true),
            page:,
            limit:,
          )
        groups = result.groups
        member_visible_group_ids =
          Group
            .where(id: groups.map(&:id))
            .members_visible_groups(
              guardian.user,
              nil,
              include_pseudogroups: true,
              include_everyone: true,
            )
            .pluck(:id)
            .to_set

        ToolHelpers.text_and_structured(
          groups:
            groups.map do |group|
              GroupSupport.group_json(
                group,
                guardian,
                membership: result.memberships[group.id],
                can_see_members: member_visible_group_ids.include?(group.id),
              )
            end,
          meta: {
            page:,
            limit:,
            total: result.total,
            has_more: (page + 1) * limit < result.total,
          },
        )
      rescue Discourse::NotFound
        raise ToolError, I18n.t("mcp.errors.group_not_found")
      end
    end

    class GetGroup
      REQUIRED_SCOPES = [Scopes::GROUPS_READ].freeze
      OUTPUT_SCHEMA = OutputSchema.object(group: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        group = GroupSupport.find_visible!(arguments, request_context.guardian)
        ToolHelpers.text_and_structured(
          group: GroupSupport.group_detail_json(group, request_context.guardian),
        )
      end
    end

    class ListGroupMembers
      REQUIRED_SCOPES = [Scopes::GROUPS_READ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(members: OutputSchema::OBJECT_ARRAY, meta: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = GroupSupport.find_visible!({ "name" => arguments.fetch("name") }, guardian)
        guardian.ensure_can_see_group_members!(group)

        users = group.listed_users.includes(:user_option, :user_stat)
        users = GroupSupport.filter_users(users, arguments["filter"], guardian)
        direction = arguments.fetch("ascending", true) ? "ASC" : "DESC"
        order =
          case arguments.fetch("order", "username")
          when "last_posted_at", "last_seen_at"
            "users.#{arguments.fetch("order")} #{direction} NULLS LAST"
          when "added_at"
            "group_users.created_at #{direction}"
          else
            "users.username_lower #{direction}"
          end
        users = users.reorder(Arel.sql(order), username_lower: direction.downcase.to_sym)
        total = users.count
        offset = arguments.fetch("offset", 0)
        limit = arguments.fetch("limit", 50)
        users = users.offset(offset).limit(limit).to_a
        memberships = group.group_users.where(user: users).index_by(&:user_id)

        ToolHelpers.text_and_structured(
          members:
            users.map do |member|
              membership = memberships.fetch(member.id)
              member_json = {
                id: member.id,
                username: member.username,
                name: SiteSetting.enable_names? ? member.name : nil,
                owner: membership.owner,
                added_at: membership.created_at.iso8601,
              }
              if guardian.can_see_profile?(member)
                member_json[:last_posted_at] = member.last_posted_at&.iso8601
                member_json[:last_seen_at] = member.last_seen_at&.iso8601
              end
              member_json
            end,
          meta: {
            offset:,
            limit:,
            total:,
            has_more: offset + limit < total,
          },
        )
      end
    end

    class ListGroupMembershipRequests
      REQUIRED_SCOPES = [Scopes::GROUPS_READ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(requests: OutputSchema::OBJECT_ARRAY, meta: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = GroupSupport.find_visible!({ "name" => arguments.fetch("name") }, guardian)
        guardian.ensure_can_edit!(group)

        requests = group.group_requests.includes(:user)
        if arguments["filter"].present?
          matching_users =
            GroupSupport.filter_users(group.requesters, arguments["filter"], guardian)
          requests = requests.where(user_id: matching_users.select("users.id"))
        end
        direction = arguments.fetch("ascending", true) ? :asc : :desc
        requests = requests.order(created_at: direction, id: direction)
        total = requests.count
        offset = arguments.fetch("offset", 0)
        limit = arguments.fetch("limit", 50)
        requests = requests.offset(offset).limit(limit)

        ToolHelpers.text_and_structured(
          requests:
            requests.map do |request|
              {
                user_id: request.user_id,
                username: request.user.username,
                name: SiteSetting.enable_names? ? request.user.name : nil,
                reason: request.reason,
                requested_at: request.created_at.iso8601,
              }
            end,
          meta: {
            offset:,
            limit:,
            total:,
            has_more: offset + limit < total,
          },
        )
      end
    end

    class ListGroupPosts
      REQUIRED_SCOPES = [Scopes::GROUPS_READ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(posts: OutputSchema::OBJECT_ARRAY, meta: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        if arguments["before_post_id"].present? && arguments["before"].present?
          raise ToolError, I18n.t("mcp.errors.group_post_single_cursor")
        end

        guardian = request_context.guardian
        group = GroupSupport.find_visible!({ "name" => arguments.fetch("name") }, guardian)
        guardian.ensure_can_see_group_members!(group)
        limit = arguments.fetch("limit", 20)
        filters = {
          before_post_id: arguments["before_post_id"],
          before: arguments["before"],
          category_id: arguments["category_id"],
        }.compact
        posts = group.posts_for(guardian, filters).limit(limit + 1).to_a
        has_more = posts.length > limit
        posts = posts.first(limit)

        ToolHelpers.text_and_structured(
          posts:
            posts.map do |post|
              ToolHelpers.evidence_post_json(
                post,
                excerpt: ToolHelpers.post_excerpt(post, guardian),
              )
            end,
          meta: {
            limit:,
            has_more:,
            next_before_post_id: has_more ? posts.last&.id : nil,
          },
        )
      end
    end
  end
end
