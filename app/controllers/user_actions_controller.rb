class UserActionsController < ApplicationController

  def index
    params.require(:username)
    params.permit(:filter, :offset)

    per_chunk = 60

    user = fetch_user_from_params

    opts = { user_id: user.id,
             user: user,
             offset: params[:offset].to_i,
             limit: per_chunk,
             action_types: (params[:filter] || "").split(",").map(&:to_i),
             guardian: guardian,
             ignore_private_messages: params[:filter] ? false : true }

    # Pending is restricted
    stream = if opts[:action_types].include?(UserAction::PENDING)
      guardian.ensure_can_see_notifications!(user)
      UserAction.stream_queued(opts)
    else
      UserAction.stream(opts)
    end

    render_serialized(stream, UserActionSerializer, root: 'user_actions')
  end

  def show
    params.require(:id)
    render_serialized(UserAction.stream_item(params[:id], guardian), UserActionSerializer)
  end

  def private_messages
    # DO NOT REMOVE
  end

end
