# frozen_string_literal: true

module Chat
  class ChannelMembershipManager
    def self.all_for_user(user)
      override = DiscoursePluginRegistry.apply_modifier(:channel_memberships, nil, user)

      return override if !override.nil?

      Chat::UserChatChannelMembership.where(user: user)
    end

    attr_reader :channel

    def initialize(channel)
      @channel = channel
    end

    def find_for_user(user, following: nil)
      params = { user_id: user.id, chat_channel_id: channel.id }
      params[:following] = following if following.present?

      Chat::UserChatChannelMembership.includes(:user, :chat_channel).find_by(params)
    end

    def follow(user)
      membership =
        find_for_user(user) ||
          Chat::UserChatChannelMembership.new(user: user, chat_channel: channel, following: true)

      override =
        DiscoursePluginRegistry.apply_modifier(
          :follow_modifier,
          nil,
          channel,
          user,
          membership,
          self,
        )

      return override if !override.nil?

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
      return if Chat::Channel.exists?(id: channel.id, user_count_stale: true)
      channel.update!(user_count_stale: true)
      Jobs.enqueue_in(3.seconds, Jobs::Chat::UpdateChannelUserCount, chat_channel_id: channel.id)
    end

    def unfollow_all_users
      Chat::UserChatChannelMembership.where(chat_channel: channel).update_all(
        following: false,
        last_read_message_id: channel.chat_messages.last&.id,
      )
    end
  end
end
