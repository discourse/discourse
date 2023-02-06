# frozen_string_literal: true

class Chat::ChatChannelMembershipManager
  def self.all_for_user(user)
    UserChatChannelMembership.where(user: user)
  end

  attr_reader :channel

  def initialize(channel)
    @channel = channel
  end

  def find_for_user(user, following: nil)
    params = { user_id: user.id, chat_channel_id: channel.id }
    params[:following] = following if following.present?

    UserChatChannelMembership.includes(:user, :chat_channel).find_by(params)
  end

  def follow(user)
    membership =
      find_for_user(user) ||
        UserChatChannelMembership.new(user: user, chat_channel: channel, following: true)

    ActiveRecord::Base.transaction do
      if membership.new_record?
        membership.save!
        recalculate_user_count
      elsif !membership.following
        membership.update!(following: true)
        recalculate_user_count
      end
    end

    membership
  end

  def unfollow(user)
    membership = find_for_user(user)

    return if membership.blank?

    ActiveRecord::Base.transaction do
      if membership.following
        membership.update!(following: false)
        recalculate_user_count
      end
    end

    membership
  end

  def recalculate_user_count
    return if ChatChannel.exists?(id: channel.id, user_count_stale: true)
    channel.update!(user_count_stale: true)
    Jobs.enqueue_in(3.seconds, :update_channel_user_count, chat_channel_id: channel.id)
  end

  def unfollow_all_users
    UserChatChannelMembership.where(chat_channel: channel).update_all(
      following: false,
      last_read_message_id: channel.chat_messages.last&.id,
    )
  end

  def enforce_automatic_channel_memberships
    Jobs.enqueue(:auto_join_channel_memberships, chat_channel_id: channel.id)
  end

  def enforce_automatic_user_membership(user)
    Jobs.enqueue(
      :auto_join_channel_batch,
      chat_channel_id: channel.id,
      starts_at: user.id,
      ends_at: user.id,
    )
  end

  def enforce_automatic_removal(event)
    allowed_events = %i[chat_allowed_groups_changed user_removed_from_group category_updated]
    return if !allowed_events.include?(event)
    Jobs.enqueue(:auto_remove_channel_memberships, chat_channel_id: channel.id)
  end

  def enforce_automatic_user_removal(user)
    Jobs.enqueue(
      :auto_remove_channel_membership_batch,
      chat_channel_id: channel.id,
      starts_at: user.id,
      ends_at: user.id,
    )
  end
end
