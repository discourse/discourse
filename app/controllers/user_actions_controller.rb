# frozen_string_literal: true

class UserActionsController < ApplicationController
  def index
    params.require(:username)
    params.permit(:filter, :offset, :acting_username, :limit)

    user = fetch_user_from_params(include_inactive: current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts))
    offset = [0, params[:offset].to_i].max
    action_types = (params[:filter] || "").split(",").map(&:to_i)
    limit = params.fetch(:limit, 30).to_i

    raise Discourse::NotFound unless guardian.can_see_profile?(user)
    raise Discourse::NotFound unless guardian.can_see_user_actions?(user, action_types)

    opts = {
      user_id: user.id,
      user: user,
      offset: offset,
      limit: limit,
      action_types: action_types,
      guardian: guardian,
      ignore_private_messages: params[:filter] ? false : true,
      acting_username: params[:acting_username]
    }

    stream = UserAction.stream(opts).to_a
    render_serialized(stream, UserActionSerializer, root: 'user_actions')
  end

  def show
    params.require(:id)
    render_serialized(UserAction.stream_item(params[:id], guardian), UserActionSerializer)
  end

  def private_messages
    # DO NOT REMOVE
    # TODO should preload messages to avoid extra http req
  end

end
