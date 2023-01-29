# frozen_string_literal: true

class Chat::Api::ChatChannelsStatusController < Chat::Api::ChatChannelsController
  def update
    status = params.require(:status)

    # we only want to use this endpoint for open/closed status changes,
    # the others are more "special" and are handled by the archive endpoint
    if !ChatChannel.statuses.keys.include?(status) || status == "read_only" || status == "archive"
      raise Discourse::InvalidParameters
    end

    guardian.ensure_can_change_channel_status!(channel_from_params, status.to_sym)
    channel_from_params.public_send("#{status}!", current_user)

    render_serialized(channel_from_params, ChatChannelSerializer, root: "channel")
  end
end
