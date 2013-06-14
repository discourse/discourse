class UserActionsController < ApplicationController
  def index
    params.require(:username)
    params.permit(:filter, :offset)

    per_chunk = 60

    user = fetch_user_from_params

    opts = {
      user_id: user.id,
      offset: params[:offset].to_i,
      limit: per_chunk,
      action_types: (params[:filter] || "").split(",").map(&:to_i),
      guardian: guardian,
      ignore_private_messages: params[:filter] ? false : true
    }

    stream =
      if opts[:action_types] == [UserAction::GOT_PRIVATE_MESSAGE] ||
         opts[:action_types] == [UserAction::NEW_PRIVATE_MESSAGE]
        UserAction.private_message_stream(opts[:action_types][0], opts)
      else
        UserAction.stream(opts)
      end

    render_serialized(stream, UserActionSerializer, root: "user_actions")
  end

  def show
    params.require(:id)
    render json: UserAction.stream_item(params[:id], guardian)
  end

  def private_messages
    # todo
  end


end
