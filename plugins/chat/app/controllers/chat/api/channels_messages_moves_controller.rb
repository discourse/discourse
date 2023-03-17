# frozen_string_literal: true

class Chat::Api::ChannelsMessagesMovesController < Chat::Api::ChannelsController
  def create
    move_params = params.require(:move)
    move_params.require(:message_ids)
    move_params.require(:destination_channel_id)

    raise Discourse::InvalidAccess if !guardian.can_move_chat_messages?(channel_from_params)
    destination_channel =
      Chat::ChannelFetcher.find_with_access_check(move_params[:destination_channel_id], guardian)

    begin
      message_ids = move_params[:message_ids].map(&:to_i)
      moved_messages =
        Chat::MessageMover.new(
          acting_user: current_user,
          source_channel: channel_from_params,
          message_ids: message_ids,
        ).move_to_channel(destination_channel)
    rescue Chat::MessageMover::NoMessagesFound, Chat::MessageMover::InvalidChannel => err
      return render_json_error(err.message)
    end

    render json:
             success_json.merge(
               destination_channel_id: destination_channel.id,
               destination_channel_title: destination_channel.title(current_user),
               first_moved_message_id: moved_messages.first.id,
             )
  end
end
