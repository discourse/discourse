# frozen_string_literal: true

module DiscourseMcp
  module Tools
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
  end
end
