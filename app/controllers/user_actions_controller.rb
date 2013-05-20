class UserActionsController < ApplicationController
  def index
    requires_parameters(:user_id)
    per_chunk = 60

    opts = {
      user_id: params[:user_id].to_i,
      offset: params[:offset],
      limit: per_chunk,
      action_types: (params[:filter] || "").split(",").map(&:to_i),
      guardian: guardian,
      ignore_private_messages: params[:filter] ? false : true
    }

    if opts[:action_types] == [UserAction::GOT_PRIVATE_MESSAGE] ||
       opts[:action_types] == [UserAction::NEW_PRIVATE_MESSAGE]
      render json: UserAction.private_message_stream(opts[:action_types][0], opts)
    else
      render json: UserAction.stream(opts)
    end
  end

  def show
    requires_parameters(:id)
    render json: UserAction.stream_item(params[:id], guardian)
  end

  def private_messages
    # todo
  end

end
