# frozen_string_literal: true

class Chat::Api::ChatChannelsStatusController < Chat::Api::ChatChannelsController
  def update
    with_service(
      Chat::Service::UpdateChannelStatus,
      extra_params: {
        channel: channel_from_params,
        status: params.require(:status),
      },
    ) { on_success { render_serialized(@_result.channel, ChatChannelSerializer, root: "channel") } }
  end
end
