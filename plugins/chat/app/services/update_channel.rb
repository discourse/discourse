# frozen_string_literal: true

module Chat
  module Service
    # Service responsible for updating a chat channel's name, slug, and description.
    #
    # For a CategoryChannel, the settings for auto_join_users and allow_channel_wide_mentions
    # are also editable.
    #
    # @example
    #  Chat::Service::UpdateChannel.call(
    #   channel: channel,
    #   guardian: guardian,
    #   name: "SuperChannel",
    #   description: "This is the best channel",
    #   slug: "super-channel",
    #  )
    #
    class UpdateChannel
      include Base

      # @!method call(channel:, guardian:, **params_to_edit)
      #   @param [ChatChannel] channel
      #   @param [Guardian] guardian
      #   @param [Hash] params_to_edit
      #   @option params_to_edit [String] name
      #   @option params_to_edit [String] description
      #   @option params_to_edit [String] slug
      #   @option params_to_edit [Boolean] auto_join_users Only valid for {CategoryChannel}. Whether active users
      #    with permission to see the category should automatically join the channel.
      #   @option params_to_edit [String] allow_channel_wide_mentions Allow the use of @here and @all in the channel.
      #   @return [Chat::Service::Base::Context]

      delegate :channel, :name, :description, :slug, to: :context

      policy(:invalid_access) { guardian.can_edit_chat_channel? }

      before_contract do
        if @initial_context.key?(:name) && context.name.blank?
          context.name = nil
        else
          context.name = (context.name || context.channel.name).presence
        end

        if @initial_context.key?(:description) && context.description.blank?
          context.description = nil
        else
          context.description = (context.description || context.channel.description).presence
        end

        context.slug = (context.slug || context.channel.slug).presence

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
        attribute :slug
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
        channel.update!(params_to_edit)
      end

      def params_to_edit
        params = { name: name, description: description, slug: slug }

        if channel.category_channel?
          params.merge!(context.to_h.slice(:auto_join_users, :allow_channel_wide_mentions))
        end

        params
      end

      def publish_channel_update
        # FIXME: this should become a dedicated service
        ChatPublisher.publish_chat_channel_edit(channel, guardian.user)
      end

      def auto_join_users_if_needed
        # FIXME: this should become a dedicated service
        if channel.category_channel? && channel.auto_join_users
          Chat::ChatChannelMembershipManager.new(channel).enforce_automatic_channel_memberships
        end
      end
    end
  end
end
