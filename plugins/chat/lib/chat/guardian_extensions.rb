# frozen_string_literal: true

module Chat
  module GuardianExtensions
    def can_moderate_chat?(chatable)
      case chatable.class.name
      when "Category"
        is_staff? || is_category_group_moderator?(chatable)
      else
        is_staff?
      end
    end

    def can_chat?
      return false if anonymous?
      @user.bot? || @user.in_any_groups?(Chat.allowed_group_ids)
    end

    def can_direct_message?
      @user.in_any_groups?(SiteSetting.direct_message_enabled_groups_map)
    end

    def can_create_chat_message?
      !SpamRule::AutoSilence.prevent_posting?(@user)
    end

    def can_create_direct_message?
      is_staff? || can_direct_message?
    end

    def hidden_tag_names
      @hidden_tag_names ||= DiscourseTagging.hidden_tag_names(self)
    end

    def can_create_chat_channel?
      is_staff?
    end

    def can_delete_chat_channel?
      is_staff?
    end

    # Channel status intentionally has no bearing on whether the channel
    # name and description can be edited.
    def can_edit_chat_channel?(channel)
      if channel.direct_message_channel?
        is_staff? || channel.chatable.user_can_access?(@user)
      elsif channel.category_channel?
        is_staff?
      end
    end

    # The only part of the thread that can be changed is the title
    # so this isn't too dangerous, if we end up wanting to change
    # more things in future we may want to re-evaluate to be staff-only here.
    def can_edit_thread?(thread)
      is_staff? || thread.original_message_user_id == @user.id
    end

    def can_move_chat_messages?(channel)
      can_moderate_chat?(channel.chatable)
    end

    def can_create_channel_message?(chat_channel)
      valid_statuses = is_staff? ? %w[open closed] : ["open"]
      valid_statuses.include?(chat_channel.status)
    end

    # This is intentionally identical to can_create_channel_message, we
    # may want to have different conditions here in future.
    def can_modify_channel_message?(chat_channel)
      return chat_channel.open? || chat_channel.closed? if is_staff?
      chat_channel.open?
    end

    def can_change_channel_status?(chat_channel, target_status)
      return false if chat_channel.status.to_sym == target_status.to_sym
      return false if !is_staff?

      # FIXME: This logic shouldn't be handled in guardian
      case target_status
      when :closed
        chat_channel.open?
      when :open
        chat_channel.closed?
      when :archived
        chat_channel.read_only?
      when :read_only
        chat_channel.closed? || chat_channel.open?
      else
        false
      end
    end

    def can_rebake_chat_message?(message)
      return false if !can_modify_channel_message?(message.chat_channel)
      is_staff? || @user.has_trust_level?(TrustLevel[4])
    end

    def can_preview_chat_channel?(chat_channel)
      return false if !chat_channel&.chatable

      if chat_channel.direct_message_channel?
        chat_channel.chatable.user_can_access?(@user)
      elsif chat_channel.category_channel?
        can_see_category?(chat_channel.chatable)
      else
        true
      end
    end

    def can_join_chat_channel?(chat_channel, post_allowed_category_ids: nil)
      return false if anonymous?
      return false unless can_chat?
      can_preview_chat_channel?(chat_channel) &&
        can_post_in_chatable?(
          chat_channel.chatable,
          post_allowed_category_ids: post_allowed_category_ids,
        )
    end

    def can_post_in_chatable?(chatable, post_allowed_category_ids: nil)
      case chatable
      when Category
        # technically when fetching channels in channel_fetcher we alread scope it to
        # categories with post_create_allowed(guardian) so this is redundant but still
        # valuable to have here when we're not fetching channels through channel_fetcher
        if post_allowed_category_ids
          return false unless chatable
          return false if is_anonymous?
          return true if is_admin?
          post_allowed_category_ids.include?(chatable.id)
        else
          can_post_in_category?(chatable)
        end
      when Chat::DirectMessage
        true
      end
    end

    def can_flag_chat_messages?
      return false if @user.silenced?
      @user.in_any_groups?(SiteSetting.chat_message_flag_allowed_groups_map)
    end

    def can_flag_in_chat_channel?(chat_channel, post_allowed_category_ids: nil)
      return false if !can_modify_channel_message?(chat_channel)

      can_join_chat_channel?(chat_channel, post_allowed_category_ids: post_allowed_category_ids)
    end

    def can_flag_chat_message?(chat_message)
      if !authenticated? || !chat_message || chat_message.trashed? || !chat_message.user
        return false
      end
      return false if chat_message.user.staff? && !SiteSetting.allow_flagging_staff
      return false if chat_message.user_id == @user.id

      can_flag_chat_messages? && can_flag_in_chat_channel?(chat_message.chat_channel)
    end

    def can_flag_message_as?(chat_message, flag_type_id, opts)
      return false if !is_staff? && (opts[:take_action] || opts[:queue_for_review])

      if flag_type_id == ReviewableScore.types[:notify_user]
        is_warning = ActiveRecord::Type::Boolean.new.deserialize(opts[:is_warning])

        return false if is_warning && !is_staff?
      end

      true
    end

    def can_delete_chat?(message, chatable)
      return false if @user.silenced?
      return false if !can_modify_channel_message?(message.chat_channel)

      if message.user_id == current_user.id
        can_delete_own_chats?(chatable)
      else
        can_delete_other_chats?(chatable)
      end
    end

    def can_delete_own_chats?(chatable)
      return false if (SiteSetting.max_post_deletions_per_day < 1)
      return true if can_moderate_chat?(chatable)

      true
    end

    def can_delete_other_chats?(chatable)
      return true if can_moderate_chat?(chatable)

      false
    end

    def can_restore_chat?(message, chatable)
      return false if !can_modify_channel_message?(message.chat_channel)

      if message.user_id == current_user.id
        case chatable
        when Category
          return message.deleted_by_id == current_user.id || can_see_category?(chatable)
        when Chat::DirectMessage
          return message.deleted_by_id == current_user.id || is_staff?
        end
      end

      can_delete_other_chats?(chatable)
    end

    def can_restore_other_chats?(chatable)
      can_moderate_chat?(chatable)
    end

    def can_edit_chat?(message)
      (message.user_id == @user.id && !@user.silenced?) || is_admin?
    end

    def can_react?
      can_create_chat_message?
    end

    def can_delete_category?(category)
      super && category.deletable_for_chat?
    end
  end
end
