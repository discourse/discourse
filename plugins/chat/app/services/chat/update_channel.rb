# frozen_string_literal: true

module Chat
  # Service responsible for updating a chat channel's name, slug, and description.
  #
  # For a CategoryChannel, the settings for auto_join_users, allow_channel_wide_mentions
  # and threading_enabled are also editable.
  #
  # @example
  #  Service::Chat::UpdateChannel.call(
  #   channel_id: 2,
  #   guardian: guardian,
  #   name: "SuperChannel",
  #   description: "This is the best channel",
  #   slug: "super-channel",
  #   threading_enabled: true,
  #  )
  #
  class UpdateChannel
    include Service::Base

    # @!method call(channel_id:, guardian:, **params_to_edit)
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @param [Hash] params_to_edit
    #   @option params_to_edit [String,nil] name
    #   @option params_to_edit [String,nil] description
    #   @option params_to_edit [String,nil] slug
    #   @option params_to_edit [Boolean] auto_join_users Only valid for {CategoryChannel}. Whether active users
    #    with permission to see the category should automatically join the channel.
    #   @option params_to_edit [Boolean] allow_channel_wide_mentions Allow the use of @here and @all in the channel.
    #   @return [Service::Base::Context]

    model :channel, :fetch_channel
    policy :no_direct_message_channel
    policy :check_channel_permission
    contract default_values_from: :channel
    step :update_channel
    step :mark_all_threads_as_read_if_needed
    step :publish_channel_update
    step :auto_join_users_if_needed

    # @!visibility private
    class Contract
      attribute :name, :string
      attribute :description, :string
      attribute :slug, :string
      attribute :threading_enabled, :boolean, default: false
      attribute :auto_join_users, :boolean, default: false
      attribute :allow_channel_wide_mentions, :boolean, default: true

      before_validation do
        assign_attributes(
          attributes.symbolize_keys.slice(:name, :description, :slug).transform_values(&:presence),
        )
      end
    end

    private

    def fetch_channel(channel_id:, **)
      Chat::Channel.find_by(id: channel_id)
    end

    def no_direct_message_channel(channel:, **)
      !channel.direct_message_channel?
    end

    def check_channel_permission(guardian:, channel:, **)
      guardian.can_preview_chat_channel?(channel) && guardian.can_edit_chat_channel?
    end

    def update_channel(channel:, contract:, **)
      channel.assign_attributes(contract.attributes)
      context.threading_enabled_changed = channel.threading_enabled_changed?
      channel.save!
    end

    def mark_all_threads_as_read_if_needed(channel:, **)
      return if !(context.threading_enabled_changed && channel.threading_enabled)
      Jobs.enqueue(Jobs::Chat::MarkAllChannelThreadsRead, channel_id: channel.id)
    end

    def publish_channel_update(channel:, guardian:, **)
      Chat::Publisher.publish_chat_channel_edit(channel, guardian.user)
    end

    def auto_join_users_if_needed(channel:, **)
      return unless channel.auto_join_users?
      Chat::ChannelMembershipManager.new(channel).enforce_automatic_channel_memberships
    end
  end
end
