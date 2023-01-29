# frozen_string_literal: true

class Chat::Api::ChatChannelsCurrentUserMembershipController < Chat::Api::ChatChannelsController
  def create
    guardian.ensure_can_join_chat_channel!(channel_from_params)

    render_serialized(
      channel_from_params.add(current_user),
      UserChatChannelMembershipSerializer,
      root: "membership",
    )
  end

  def destroy
    render_serialized(
      channel_from_params.remove(current_user),
      UserChatChannelMembershipSerializer,
      root: "membership",
    )
  end
end
