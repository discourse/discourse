# frozen_string_literal: true

class Chat::Api::ChatChannelsStatusController < Chat::Api::ChatChannelsController
  def update
    with_service(Chat::Service::UpdateChannelStatus) do
      on_success { render_serialized(result.channel, ChatChannelSerializer, root: "channel") }
      on_model_not_found(:channel) { raise ActiveRecord::RecordNotFound }
      on_failed_policy(:check_channel_permission) { raise Discourse::InvalidAccess }
    end
  end
end
