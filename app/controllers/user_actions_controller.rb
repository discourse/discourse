class UserActionsController < ApplicationController
  def index
    requires_parameters(:user_id)
    per_chunk = 60
    render :json => UserAction.stream(
      user_id: params[:user_id].to_i,
      offset: params[:offset],
      limit: per_chunk,
      action_types: (params[:filter] || "").split(","),
      guardian: guardian,
      ignore_private_messages: params[:filter] ? false : true
    )
  end

  def show
    requires_parameters(:id)
    render :json => UserAction.stream_item(params[:id], guardian)
  end

  def private_messages
    # todo
  end

end
