# frozen_string_literal: true

require "group_directory_query"

module DiscourseMcp
  module Tools
    module GroupSupport
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

      def find_managed!(group_id, guardian)
        group = Group.visible_groups(guardian.user).find_by(id: group_id)
        group or raise ToolError, I18n.t("mcp.errors.group_not_found")
      end

      def user_selectors!(arguments)
        selectors = {
          usernames: arguments["usernames"],
          user_ids: arguments["user_ids"],
          user_emails: arguments["user_emails"],
        }.compact_blank
        raise ToolError, I18n.t("mcp.errors.group_member_selector_required") if selectors.size != 1

        limit = ManageGroupMembers::MAX_SELECTED_USERS
        if GroupMutations.split_values(selectors.values.first).size > limit
          raise ToolError, I18n.t("mcp.errors.group_user_limit", count: limit)
        end

        selectors.merge(require_all: true)
      end

      def group_json(group, guardian, membership:, can_see_members:)
        is_group_owner = membership&.owner? || false
        can_admin_group = guardian.can_admin_group?(group, is_group_owner:)
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
          is_group_owner:,
          can_see_members:,
          can_edit_group: guardian.can_edit_group?(group, is_group_owner:),
          can_admin_group:,
        }
      end

      # Whether a group has personal messages, and how many, describes those
      # messages, so both are left out while agent access to them is off.
      PRIVATE_MESSAGE_FIELDS = %i[has_messages message_count].freeze
      # The group's notification defaults for categories and tags.
      DEFAULT_CATEGORY_FIELDS = %i[
        watching_category_ids
        tracking_category_ids
        watching_first_post_category_ids
        regular_category_ids
        muted_category_ids
      ].freeze
      DEFAULT_TAG_FIELDS = %i[
        watching_tags
        watching_first_post_tags
        tracking_tags
        regular_tags
        muted_tags
      ].freeze

      def group_detail_json(group, request_context)
        fields = SAFE_DETAIL_FIELDS
        fields -= PRIVATE_MESSAGE_FIELDS if ToolHelpers.private_messages_denied?(request_context)

        json =
          GroupShowSerializer
            .new(group, scope: request_context.guardian, root: false)
            .as_json
            .slice(*fields)
        without_restricted_defaults(json, request_context.content_policy)
      end

      def without_restricted_defaults(json, policy)
        return json if !policy.restricts_forum?

        DEFAULT_CATEGORY_FIELDS.each do |field|
          next if !json[field].is_a?(Array)
          json[field] = json[field].select { |id| policy.allows_category_id?(id) }
        end
        DEFAULT_TAG_FIELDS.each do |field|
          next if !json[field].is_a?(Array)
          json[field] = json[field].select { |name| policy.allows_tag?(name) }
        end
        json
      end

      # Setting notification defaults to categories or tags can't be checked
      # against restrictions without revealing which ones are restricted, so
      # agents can't set them while a rule narrows topics.
      def ensure_defaults_unrestricted!(arguments, request_context)
        return if !request_context.content_policy.restricts_forum?

        keys = (DEFAULT_CATEGORY_FIELDS + DEFAULT_TAG_FIELDS).map(&:to_s)
        return if arguments.keys.none? { |key| keys.include?(key) }

        request_context.content_policy.require_unrestricted!(ContentPolicy::CATEGORIES)
      end

      # Membership requests and their reasons become personal messages, so agents
      # can't make or act on them while agent access to personal messages is off.
      def ensure_private_messages_allowed!(request_context)
        return if !ToolHelpers.private_messages_denied?(request_context)

        raise ToolError, I18n.t("mcp.errors.content_policy_blocked")
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
      CONTENT = {
        topics: :untouched,
        private_messages: :untouched,
        categories: :untouched,
        tags: :untouched,
        exit_paths: :untouched,
      }.freeze
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
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema.object(group: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        group = GroupSupport.find_visible!(arguments, request_context.guardian)
        ToolHelpers.text_and_structured(
          group: GroupSupport.group_detail_json(group, request_context),
        )
      end
    end

    class ListGroupMembers
      REQUIRED_SCOPES = [Scopes::GROUPS_READ].freeze
      CONTENT = {
        topics: :untouched,
        private_messages: :untouched,
        categories: :untouched,
        tags: :untouched,
        exit_paths: :untouched,
      }.freeze
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
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
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
                # The reason is the body of the request's personal message.
                reason: request_context.content_policy.active? ? nil : request.reason,
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

    class CreateGroup
      REQUIRED_SCOPES = [Scopes::GROUPS_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :untouched,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      # The MCP registry is built before app models are loadable, so these
      # mirror Group.visibility_levels, Group::ALIAS_LEVELS and
      # GroupUser.notification_levels. A spec guards them against drift.
      VISIBILITY_LEVELS = [0, 1, 2, 3, 4].freeze
      ALIAS_LEVELS = [0, 1, 2, 3, 4, 99].freeze
      NOTIFICATION_LEVELS = [0, 1, 2, 3, 4].freeze
      MAX_NAME_LENGTH = 100
      MAX_BIO_LENGTH = 3_000
      MAX_TEMPLATE_LENGTH = 1_000
      MAX_INITIAL_USERNAMES = 100
      OUTPUT_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER,
          name: OutputSchema::STRING,
          full_name: OutputSchema::STRING_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        GroupSupport.ensure_defaults_unrestricted!(arguments, request_context)
        created = nil
        message = nil

        Groups::Create.call(guardian:, params: arguments.symbolize_keys) do
          on_success { |group:| created = group }
          on_failed_policy(:can_create_group) { raise Discourse::InvalidAccess }
          on_failed_policy(:can_request_access) do
            message = I18n.t("groups.errors.cant_allow_membership_requests")
          end
          on_failed_contract { |contract| message = contract.errors.full_messages.to_sentence }
          on_model_errors(:group) { |group:| message = group.errors.full_messages.to_sentence }
        end

        if created.nil?
          raise ToolError, message.presence || I18n.t("mcp.errors.group_create_failed")
        end

        ToolHelpers.text_and_structured(
          id: created.id,
          name: created.name,
          full_name: created.full_name,
        )
      end
    end

    class UpdateGroup
      REQUIRED_SCOPES = [Scopes::GROUPS_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      MAX_NAME_LENGTH = CreateGroup::MAX_NAME_LENGTH
      MAX_BIO_LENGTH = CreateGroup::MAX_BIO_LENGTH
      MAX_TEMPLATE_LENGTH = CreateGroup::MAX_TEMPLATE_LENGTH
      OUTPUT_SCHEMA = OutputSchema.object(group: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = GroupSupport.find_managed!(arguments.fetch("group_id"), guardian)
        GroupSupport.ensure_defaults_unrestricted!(arguments, request_context)
        attributes = arguments.slice(*GroupUpdater.permitted_names(guardian, group:))
        raise ToolError, I18n.t("mcp.errors.group_update_required") if attributes.empty?

        updated =
          GroupUpdater.update(
            guardian,
            group,
            attributes,
            update_existing_users: arguments["update_existing_users"],
          )
        if !updated
          raise ToolError,
                group.errors.full_messages.to_sentence.presence ||
                  I18n.t("mcp.errors.group_update_failed")
        end

        ToolHelpers.text_and_structured(
          group: GroupSupport.group_detail_json(group.reload, request_context),
        )
      rescue GroupUpdater::ExistingUsersConfirmationRequired => error
        raise ToolError,
              I18n.t("mcp.errors.group_update_existing_users_required", count: error.user_count)
      end
    end

    class DeleteGroup
      REQUIRED_SCOPES = [Scopes::GROUPS_WRITE].freeze
      CONTENT = {
        topics: :untouched,
        private_messages: :untouched,
        categories: :untouched,
        tags: :untouched,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(deleted: OutputSchema::BOOLEAN, group_id: OutputSchema::INTEGER)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = GroupSupport.find_managed!(arguments.fetch("group_id"), guardian)
        GroupDestroyer.ensure_allowed!(guardian, group)

        if arguments["confirm"] != true
          raise ToolError, I18n.t("mcp.errors.group_delete_confirmation_required")
        end
        if arguments.fetch("expected_name") != group.name
          raise ToolError, I18n.t("mcp.errors.group_delete_name_mismatch")
        end

        group_id = group.id
        GroupDestroyer.destroy(guardian, group)
        ToolHelpers.text_and_structured(deleted: true, group_id:)
      rescue GroupMutations::AutomaticGroup => error
        raise ToolError, error.message
      end
    end

    class ManageGroupMembers
      REQUIRED_SCOPES = [Scopes::GROUPS_WRITE].freeze
      CONTENT = {
        topics: :untouched,
        private_messages: :untouched,
        categories: :untouched,
        tags: :untouched,
        exit_paths: :untouched,
      }.freeze
      ACTIONS = %w[add remove].freeze
      MAX_SELECTED_USERS = 100
      OUTPUT_SCHEMA =
        OutputSchema.object(
          action: OutputSchema::STRING,
          group_id: OutputSchema::INTEGER,
          usernames: OutputSchema::STRING_ARRAY,
          skipped_usernames: OutputSchema::STRING_ARRAY,
          user_count: OutputSchema::INTEGER,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = GroupSupport.find_managed!(arguments.fetch("group_id"), guardian)
        selectors = GroupSupport.user_selectors!(arguments)
        action = arguments.fetch("action")

        result =
          if action == "add"
            GroupMemberAdder.add(
              guardian,
              group,
              notify_users: arguments["notify_users"],
              **selectors,
            )
          else
            GroupMemberRemover.remove(guardian, group, **selectors)
          end

        ToolHelpers.text_and_structured(
          action:,
          group_id: group.id,
          usernames: action == "add" ? result[:added_usernames] : result[:usernames],
          skipped_usernames: result[:skipped_usernames] || [],
          user_count: group.reload.user_count,
        )
      rescue GroupMemberAdder::EmailsNotAllowed,
             GroupMemberAdder::TooManyUsers,
             GroupMemberAdder::AlreadyMembers,
             GroupMutations::UnknownUsers => error
        raise ToolError, error.message
      end
    end

    class InviteGroupMembers
      REQUIRED_SCOPES = [Scopes::GROUPS_WRITE].freeze
      CONTENT = {
        topics: :untouched,
        private_messages: :untouched,
        categories: :untouched,
        tags: :untouched,
        exit_paths: :untouched,
      }.freeze
      MAX_EMAILS = 50
      OUTPUT_SCHEMA =
        OutputSchema.object(
          group_id: OutputSchema::INTEGER,
          usernames: OutputSchema::STRING_ARRAY,
          emails: OutputSchema::STRING_ARRAY,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = GroupSupport.find_managed!(arguments.fetch("group_id"), guardian)
        # GroupMutations guards the user_emails selector, but this tool passes
        # addresses as `emails`, and the response names the accounts they matched.
        guardian.ensure_can_see_emails!

        result =
          GroupMemberAdder.add(
            guardian,
            group,
            emails: arguments.fetch("emails"),
            skip_email: arguments.fetch("skip_email", false),
          )

        ToolHelpers.text_and_structured(
          group_id: group.id,
          usernames: result[:usernames],
          emails: result[:emails],
        )
      rescue GroupMemberAdder::EmailsNotAllowed, GroupMemberAdder::AlreadyMembers => error
        raise ToolError, error.message
      end
    end

    class ManageGroupOwners
      REQUIRED_SCOPES = [Scopes::GROUPS_WRITE].freeze
      CONTENT = {
        topics: :untouched,
        private_messages: :untouched,
        categories: :untouched,
        tags: :untouched,
        exit_paths: :untouched,
      }.freeze
      ACTIONS = %w[add remove].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          action: OutputSchema::STRING,
          group_id: OutputSchema::INTEGER,
          usernames: OutputSchema::STRING_ARRAY,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = GroupSupport.find_managed!(arguments.fetch("group_id"), guardian)
        selectors = GroupSupport.user_selectors!(arguments)
        action = arguments.fetch("action")

        result =
          if action == "add"
            GroupOwnerManager.add(
              guardian,
              group,
              notify_users: arguments.fetch("notify_users", false),
              **selectors,
            )
          else
            GroupOwnerManager.remove(guardian, group, **selectors)
          end

        ToolHelpers.text_and_structured(action:, group_id: group.id, usernames: result[:usernames])
      rescue GroupMutations::AutomaticGroup, GroupMutations::UnknownUsers => error
        raise ToolError, error.message
      end
    end

    class ManageGroupMembership
      REQUIRED_SCOPES = [Scopes::GROUPS_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      ACTIONS = %w[join leave request].freeze
      MAX_REASON_LENGTH = 1_000
      OUTPUT_SCHEMA =
        OutputSchema.object(
          action: OutputSchema::STRING,
          group_id: OutputSchema::INTEGER,
          changed: OutputSchema::BOOLEAN,
          member: OutputSchema::BOOLEAN,
          topic_id: OutputSchema::INTEGER_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = GroupSupport.find_managed!(arguments.fetch("group_id"), guardian)
        action = arguments.fetch("action")
        topic_id = nil

        changed =
          case action
          when "join"
            GroupSelfMembership.join(guardian, group)
          when "leave"
            GroupSelfMembership.leave(guardian, group)
          else
            reason = arguments["reason"].to_s.strip
            raise ToolError, I18n.t("mcp.errors.group_request_reason_required") if reason.blank?
            GroupSupport.ensure_private_messages_allowed!(request_context)

            topic_id = GroupMembershipRequester.request(guardian, group, reason).topic_id
            true
          end

        ToolHelpers.text_and_structured(
          action:,
          group_id: group.id,
          changed:,
          member: group.users.exists?(id: request_context.user_id),
          topic_id:,
        )
      rescue GroupMembershipRequester::AlreadyRequested => error
        raise ToolError, error.message
      end
    end

    class HandleGroupMembershipRequest
      REQUIRED_SCOPES = [Scopes::GROUPS_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      ACTIONS = %w[approve deny].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          group_id: OutputSchema::INTEGER,
          username: OutputSchema::STRING,
          action: OutputSchema::STRING,
          accepted: OutputSchema::BOOLEAN,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        group = GroupSupport.find_managed!(arguments.fetch("group_id"), guardian)
        guardian.ensure_can_edit!(group)
        GroupSupport.ensure_private_messages_allowed!(request_context)

        user = User.find_by_username(arguments.fetch("username"))
        raise ToolError, I18n.t("mcp.errors.user_not_found") if user.blank?
        if !GroupRequest.exists?(group_id: group.id, user_id: user.id)
          raise ToolError, I18n.t("mcp.errors.group_membership_request_not_found")
        end

        action = arguments.fetch("action")
        accepted = action == "approve"
        # Approving replies in the request's personal message. When the policy
        # restricts that message, it's treated like a missing one: the user is
        # added and no reply is posted.
        GroupMembershipRequestHandler.handle(
          guardian,
          group,
          user,
          accept: accepted,
          reply_allowed: ->(topic) { request_context.content_policy.allows_topic?(topic) },
        )

        ToolHelpers.text_and_structured(
          group_id: group.id,
          username: user.username,
          action:,
          accepted:,
        )
      end
    end

    class ListGroupPosts
      REQUIRED_SCOPES = [Scopes::GROUPS_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :untouched,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
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
        policy = request_context.content_policy
        if !policy.allows_category_id?(filters[:category_id])
          filters[:category_id] = ContentPolicy::MISSING_ID
        end
        posts = policy.scope_posts(group.posts_for(guardian, filters)).limit(limit + 1).to_a
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
