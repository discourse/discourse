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

    render_serialized(UserAction.stream(opts), UserActionSerializer, root: "user_actions")
  end

  def show
    params.require(:id)
    render json: UserAction.stream_item(params[:id], guardian)
  end

  def private_messages
    # todo
  end


end
