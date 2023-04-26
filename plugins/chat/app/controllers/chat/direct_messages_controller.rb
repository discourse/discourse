# frozen_string_literal: true

module Chat
  class DirectMessagesController < ::Chat::BaseController
    # NOTE: For V1 of chat channel archiving and deleting we are not doing
    # anything for DM channels, their behaviour will stay as is.
    def create
      guardian.ensure_can_chat!
      users = users_from_usernames(current_user, params)

      begin
        chat_channel =
          Chat::DirectMessageChannelCreator.create!(acting_user: current_user, target_users: users)
        render_serialized(
          chat_channel,
          Chat::ChannelSerializer,
          root: "channel",
          membership: chat_channel.membership_for(current_user),
        )
      rescue Chat::DirectMessageChannelCreator::NotAllowed => err
        render_json_error(err.message)
      end
    end

    def index
      guardian.ensure_can_chat!
      users = users_from_usernames(current_user, params)

      direct_message = Chat::DirectMessage.for_user_ids(users.map(&:id).uniq)
      if direct_message
        chat_channel = Chat::Channel.find_by(chatable_id: direct_message)
        render_serialized(
          chat_channel,
          Chat::ChannelSerializer,
          root: "channel",
          membership: chat_channel.membership_for(current_user),
        )
      else
        render body: nil, status: 404
      end
    end

    private

    def users_from_usernames(current_user, params)
      params.require(:usernames)

      usernames =
        (params[:usernames].is_a?(String) ? params[:usernames].split(",") : params[:usernames])

      users = [current_user]
      other_usernames = usernames - [current_user.username]
      users.concat(User.where(username: other_usernames).to_a) if other_usernames.any?
      users
    end
  end
end
