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
    #   channel_id: 2,
    #   guardian: guardian,
    #   name: "SuperChannel",
    #   description: "This is the best channel",
    #   slug: "super-channel",
    #  )
    #
    class UpdateChannel
      include Base

      # @!method call(channel_id:, guardian:, **params_to_edit)
      #   @param [Integer] channel_id
      #   @param [Guardian] guardian
      #   @param [Hash] params_to_edit
      #   @option params_to_edit [String] name
      #   @option params_to_edit [String] description
      #   @option params_to_edit [String] slug
      #   @option params_to_edit [Boolean] auto_join_users Only valid for {CategoryChannel}. Whether active users
      #    with permission to see the category should automatically join the channel.
      #   @option params_to_edit [String] allow_channel_wide_mentions Allow the use of @here and @all in the channel.
      #   @return [Chat::Service::Base::Context]

      model :channel, :fetch_channel
      policy :no_direct_message_channel
      policy :check_channel_permission
      step :map_data
      contract
      step :assign_contract
      step :prepare_params
      step :update_channel
      step :publish_channel_update
      step :auto_join_users_if_needed

      # @!visibility private
      class Contract
        attribute :name
        attribute :description
        attribute :slug
        attribute :auto_join_users, :boolean, default: false
        attribute :allow_channel_wide_mentions, :boolean, default: true
      end

      private

      def fetch_channel(channel_id:, **)
        ChatChannel.find_by(id: channel_id)
      end

      def no_direct_message_channel(channel:, **)
        !channel.direct_message_channel?
      end

      def check_channel_permission(guardian:, channel:, **)
        guardian.can_preview_chat_channel?(channel) && guardian.can_edit_chat_channel?
      end

      def map_data(channel:, **)
        if context.to_h.key?(:name) && context.name.blank?
          context.name = nil
        else
          context.name = (context.name || channel.name).presence
        end

        if context.to_h.key?(:description) && context.description.blank?
          context.description = nil
        else
          context.description = (context.description || channel.description).presence
        end

        context.slug = (context.slug || channel.slug).presence

        if channel.category_channel?
          context.auto_join_users ||= channel.auto_join_users
          context.allow_channel_wide_mentions ||= channel.allow_channel_wide_mentions
        end
      end

      def assign_contract
        context[:contract] = context[:"contract.default"]
      end

      def prepare_params(channel:, contract:, **)
        attributes = contract.attributes.symbolize_keys
        context[:params_to_edit] = attributes.slice(:name, :description, :slug)
        if channel.category_channel?
          context[:params_to_edit].merge!(
            attributes.slice(:auto_join_users, :allow_channel_wide_mentions),
          )
        end
      end

      def update_channel(channel:, params_to_edit:, **)
        channel.update!(params_to_edit)
      end

      def publish_channel_update(channel:, guardian:, **)
        # FIXME: this should become a dedicated service
        ChatPublisher.publish_chat_channel_edit(channel, guardian.user)
      end

      def auto_join_users_if_needed(channel:, **)
        # FIXME: this should become a dedicated service
        if channel.category_channel? && channel.auto_join_users?
          Chat::ChatChannelMembershipManager.new(channel).enforce_automatic_channel_memberships
        end
      end
    end
  end
end
