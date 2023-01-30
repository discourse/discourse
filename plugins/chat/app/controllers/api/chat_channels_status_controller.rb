# frozen_string_literal: true

class Chat::Api::ChatChannelsStatusController < Chat::Api::ChatChannelsController
  def update
    wrap_service(
      Chat::Service::UpdateChannelStatus.call(
        guardian: guardian,
        channel: channel_from_params,
        status: params.require(:status),
      ),
    ) do |success, result, controller_response|
      return render controller_response if !success

      render_serialized(result.channel, ChatChannelSerializer, root: "channel")
    end
  end
end
