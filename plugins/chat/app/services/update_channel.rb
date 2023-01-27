# frozen_string_literal: true

module Chat
  module Service
    # Service responsible for updating a chat channel's name and description.
    #
    # For a CategoryChannel, the settings for auto_join_users and allow_channel_wide_mentions
    # are also editable.
    #
    # @example
    #  Chat::Service::UpdateChannel.call(channel: channel, guardian: guardian, )
    #
    class UpdateChannel
      include Base

      before_contract { guardian(:can_edit_chat_channel?) }

      contract do
        attribute :channel
        validates :channel, presence: true

        attribute :name
        attribute :description
        attribute :auto_join_users, :boolean
        attribute :allow_channel_wide_mentions, :boolean

        validate :only_category_channel_allowed

        def only_category_channel_allowed
          if channel.direct_message_channel?
            errors.add(:base, I18n.t("chat.errors.cant_update_direct_message_channel"))
          end
        end

        def change_attribute_defaults(params)
          self.name = channel.name if !params.key?(:name)
          self.description = channel.description if !params.key?(:description)

          if self.channel.category_channel?
            self.auto_join_users =
              self.auto_join_users.nil? ? self.channel.auto_join_users : self.auto_join_users
            self.allow_channel_wide_mentions =
              (
                if self.allow_channel_wide_mentions.nil?
                  self.channel.allow_channel_wide_mentions
                else
                  self.allow_channel_wide_mentions
                end
              )
          end
        end
      end

      service do
        update_channel
        publish_channel_edit
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

      def publish_channel_edit
        ChatPublisher.publish_chat_channel_edit(context.channel, context.guardian.user)
      end

      def auto_join_users_if_needed
        if context.channel.category_channel? && context.channel.auto_join_users
          Chat::ChatChannelMembershipManager.new(
            context.channel,
          ).enforce_automatic_channel_memberships
        end
      end
    end
  end
end
