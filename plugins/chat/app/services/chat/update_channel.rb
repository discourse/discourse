# frozen_string_literal: true

module Chat
  # Service responsible for updating a chat channel's name, slug, and description.
  #
  # For a CategoryChannel, the settings for auto_join_users, allow_channel_wide_mentions
  # and threading_enabled are also editable.
  #
  # @example
  #  ::Chat::UpdateChannel.call(
  #   guardian: guardian,
  #   params:{
  #     channel_id: 2,
  #     name: "SuperChannel",
  #     description: "This is the best channel",
  #     slug: "super-channel",
  #     threading_enabled: true
  #   },
  #  )
  #

  class UpdateChannel
    include Service::Base

    # @!method self.call(params:, guardian:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id The channel ID
    #   @option params [String,nil] :name
    #   @option params [String,nil] :description
    #   @option params [String,nil] :slug
    #   @option params [Integer,nil] :icon_upload_id
    #   @option params [Boolean] :threading_enabled
    #   @option params [Boolean] :auto_join_users Only valid for {CategoryChannel}. Whether active users with permission to see the category should automatically join the channel.
    #   @option params [Boolean] :allow_channel_wide_mentions Allow the use of @here and @all in the channel.
    #   @return [Service::Base::Context]

    model :channel
    policy :check_channel_permission
    params(default_values_from: :channel) do
      attribute :name, :string
      attribute :description, :string
      attribute :slug, :string
      attribute :threading_enabled, :boolean, default: false
      attribute :auto_join_users, :boolean, default: false
      attribute :allow_channel_wide_mentions, :boolean, default: true
      attribute :icon_upload_id, :integer, default: nil

      before_validation do
        assign_attributes(
          attributes.symbolize_keys.slice(:name, :description, :slug).transform_values(&:presence),
        )
      end
    end
    step :update_channel
    step :mark_all_threads_as_read_if_needed
    step :update_site_settings_if_needed
    step :publish_channel_update
    step :auto_join_users_if_needed

    private

    def fetch_channel(params:)
      Chat::Channel.find_by(id: params[:channel_id])
    end

    def check_channel_permission(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel) && guardian.can_edit_chat_channel?(channel)
    end

    def update_channel(channel:, params:)
      channel.update!(**params)
    end

    def mark_all_threads_as_read_if_needed(channel:)
      return unless channel.threading_enabled_previously_changed?(to: true)
      Jobs.enqueue(Jobs::Chat::MarkAllChannelThreadsRead, channel_id: channel.id)
    end

    def update_site_settings_if_needed
      SiteSetting.chat_threads_enabled = Chat::Channel.exists?(threading_enabled: true)
    end

    def publish_channel_update(channel:, guardian:)
      Chat::Publisher.publish_chat_channel_edit(channel, guardian.user)
    end

    def auto_join_users_if_needed(channel:)
      Chat::AutoJoinChannels.call(params: { channel_id: channel.id }) if channel.auto_join_users?
    end
  end
end
