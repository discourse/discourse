# frozen_string_literal: true

class Chat::Api::ChannelsStatusController < Chat::Api::ChannelsController
  def update
    with_service(Chat::UpdateChannelStatus) do
      on_success { render_serialized(result.channel, Chat::ChannelSerializer, root: "channel") }
      on_model_not_found(:channel) { raise ActiveRecord::RecordNotFound }
      on_failed_policy(:check_channel_permission) { raise Discourse::InvalidAccess }
    end
  end
end
