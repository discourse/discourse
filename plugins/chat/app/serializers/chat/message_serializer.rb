# frozen_string_literal: true

module Chat
  class MessageSerializer < ::ApplicationSerializer
    BASIC_ATTRIBUTES = %i[
      id
      message
      cooked
      created_at
      excerpt
      deleted_at
      deleted_by_id
      thread_id
      chat_channel_id
      streaming
    ]
    attributes(
      *(
        BASIC_ATTRIBUTES +
          %i[
            user
            mentioned_users
            reactions
            bookmark
            available_flags
            user_flag_status
            reviewable_id
            edited
            thread
            blocks
          ]
      ),
    )

    has_one :chat_webhook_event, serializer: Chat::WebhookEventSerializer, embed: :objects
    has_one :in_reply_to, serializer: Chat::InReplyToSerializer, embed: :objects
    has_many :uploads, serializer: ::UploadSerializer, embed: :objects

    def mentioned_users
      object
        .user_mentions
        .includes(user: :user_option)
        .limit(SiteSetting.max_mentions_per_chat_message)
        .map(&:user)
        .compact
        .sort_by(&:id)
        .map { |user| BasicUserSerializer.new(user, root: false, include_status: true) }
        .as_json
    end

    def channel
      @channel ||= @options.dig(:chat_channel) || object.chat_channel
    end

    def user
      user = object.user || Chat::NullUser.new
      MessageUserSerializer.new(user, root: false, include_status: true).as_json
    end

    def excerpt
      object.excerpt || object.build_excerpt
    end

    def reactions
      object
        .reactions
        .includes(user: :user_option)
        .group_by(&:emoji)
        .map do |emoji, reactions|
          next unless Emoji.exists?(emoji)

          users = reactions.take(5).map(&:user)

          {
            emoji: emoji,
            count: reactions.count,
            users:
              ActiveModel::ArraySerializer.new(users, each_serializer: BasicUserSerializer).as_json,
            reacted: users_reactions.include?(emoji),
          }
        end
        .compact
    end

    def include_reactions?
      object.reactions.any?
    end

    def users_reactions
      @users_reactions ||=
        object.reactions.select { |reaction| reaction.user_id == scope&.user&.id }.map(&:emoji)
    end

    def users_bookmark
      @user_bookmark ||= object.bookmarks.find { |bookmark| bookmark.user_id == scope&.user&.id }
    end

    def include_bookmark?
      users_bookmark.present?
    end

    def bookmark
      {
        id: users_bookmark.id,
        reminder_at: users_bookmark.reminder_at,
        name: users_bookmark.name,
        auto_delete_preference: users_bookmark.auto_delete_preference,
        bookmarkable_id: users_bookmark.bookmarkable_id,
        bookmarkable_type: users_bookmark.bookmarkable_type,
      }
    end

    def edited
      true
    end

    def include_edited?
      object.revisions.any?
    end

    def created_at
      object.created_at.iso8601
    end

    def deleted_at
      object.user ? object.deleted_at.iso8601 : Time.zone.now
    end

    def deleted_by_id
      object.user ? object.deleted_by_id : Discourse.system_user.id
    end

    def include_deleted_at?
      object.user ? !object.deleted_at.nil? : true
    end

    def include_deleted_by_id?
      object.user ? !object.deleted_at.nil? : true
    end

    def include_in_reply_to?
      object.in_reply_to_id.presence
    end

    def reviewable_id
      return @reviewable_id if defined?(@reviewable_id)
      return @reviewable_id = nil unless @options && @options[:reviewable_ids]

      @reviewable_id = @options[:reviewable_ids][object.id]
    end

    def include_reviewable_id?
      reviewable_id.present?
    end

    def user_flag_status
      return @user_flag_status if defined?(@user_flag_status)
      return @user_flag_status = nil unless @options&.dig(:user_flag_statuses)

      @user_flag_status = @options[:user_flag_statuses][object.id]
    end

    def include_user_flag_status?
      user_flag_status.present?
    end

    def blocks
      ActiveModel::ArraySerializer.new(
        object.blocks || [],
        each_serializer: Chat::BlockSerializer,
        scope:,
        root: false,
      ).as_json
    end

    def available_flags
      return [] if !scope.can_flag_chat_message?(object)
      return [] if reviewable_id.present? && user_flag_status == ReviewableScore.statuses[:pending]

      PostActionType.flag_types.map do |sym, id|
        next if channel.direct_message_channel? && %i[notify_moderators notify_user].include?(sym)

        if sym == :notify_user &&
             (
               scope.current_user == user || object.user.bot? ||
                 !scope.current_user.in_any_groups?(SiteSetting.personal_message_enabled_groups_map)
             )
          next
        end

        sym
      end
    end

    def include_thread_id?
      channel.threading_enabled || object.thread&.force
    end

    def include_thread?
      include_thread_id? && object.thread_om? && object.thread.present?
    end

    def thread
      Chat::ThreadSerializer.new(
        object.thread,
        scope: scope,
        membership: @options[:thread_memberships]&.find { |m| m.thread_id == object.thread&.id },
        participants: @options[:thread_participants]&.dig(object.thread&.id),
        include_thread_preview: true,
        include_thread_original_message: @options[:include_thread_original_message],
        root: false,
      )
    end
  end
end
