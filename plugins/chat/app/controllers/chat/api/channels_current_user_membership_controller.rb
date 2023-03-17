# frozen_string_literal: true

class Chat::Api::ChannelsCurrentUserMembershipController < Chat::Api::ChannelsController
  def create
    guardian.ensure_can_join_chat_channel!(channel_from_params)

    render_serialized(
      channel_from_params.add(current_user),
      Chat::UserChannelMembershipSerializer,
      root: "membership",
    )
  end

  def destroy
    render_serialized(
      channel_from_params.remove(current_user),
      Chat::UserChannelMembershipSerializer,
      root: "membership",
    )
  end
end
