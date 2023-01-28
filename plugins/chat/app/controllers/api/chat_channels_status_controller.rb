# frozen_string_literal: true

class Chat::Api::ChatChannelsStatusController < Chat::Api::ChatChannelsController
  def update
    result =
      Chat::Service::UpdateChannelStatus.call(
        guardian: guardian,
        channel: channel_from_params,
        status: params.require(:status),
      )

    if result.success?
      render_serialized(channel_from_params, ChatChannelSerializer, root: "channel")
    else
      # FIXME: implement failure handling
    end
  end
end
