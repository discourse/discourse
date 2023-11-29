# frozen_string_literal: true

class Chat::Api::ChannelsCurrentUserMembershipFollowsController < Chat::Api::ChannelsController
  def destroy
    with_service(Chat::UnfollowChannel) do
      on_success do
        render_serialized(
          result.membership,
          Chat::UserChannelMembershipSerializer,
          root: "membership",
        )
      end
    end
  end
end
