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
    with_service(Chat::LeaveChannel) { on_model_not_found(:channel) { raise Discourse::NotFound } }
  end
end
