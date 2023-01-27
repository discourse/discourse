# frozen_string_literal: true

module Chat
  module Service
    # Service responsible for updating a chat channel's name and description.
    #
    # For a CategoryChannel, the settings for auto_join_users and allow_channel_wide_mentions
    # are also editable.
    #
    # @example
    #  Chat::Service::UpdateChannel.call(channel: channel, guardian: guardian)
    #
    class UpdateChannel
      include Base

      # @!method call(channel:, guardian:)
      #   @param [ChatChannel] channel
      #   @param [Guardian] guardian
      #   @return [Chat::Service::Base::Context]

      before_contract { guardian(:can_edit_chat_channel?) }

      before_contract do
        context.name = (context.name || context.channel.name).presence
        context.description = (context.description || context.channel.description).presence

        if context.channel.category_channel?
          context.auto_join_users ||= context.channel.auto_join_users
          context.allow_channel_wide_mentions ||= context.channel.allow_channel_wide_mentions
        end
      end

      contract do
        attribute :channel
        validates :channel, presence: true

        attribute :name
        attribute :description
        attribute :auto_join_users, :boolean, default: false
        attribute :allow_channel_wide_mentions, :boolean, default: true

        validate :only_category_channel_allowed

        def only_category_channel_allowed
          if channel.direct_message_channel?
            errors.add(:base, I18n.t("chat.errors.cant_update_direct_message_channel"))
          end
        end
      end

      service do
        update_channel
        publish_channel_update
        auto_join_users_if_needed
      end

      private

      def update_channel
        context.channel.update!(params_to_edit)
      end

      def params_to_edit
        params = { name: context.name, description: context.description }

        if context.channel.category_channel?
          params.merge!(
            auto_join_users: context.auto_join_users,
            allow_channel_wide_mentions: context.allow_channel_wide_mentions,
          )
        end

        params
      end

      def publish_channel_update
        # FIXME: this should become a dedicated service
        ChatPublisher.publish_chat_channel_edit(context.channel, context.guardian.user)
      end

      def auto_join_users_if_needed
        # FIXME: this should become a dedicated service
        if context.channel.category_channel? && context.channel.auto_join_users
          Chat::ChatChannelMembershipManager.new(
            context.channel,
          ).enforce_automatic_channel_memberships
        end
      end
    end
  end
end
