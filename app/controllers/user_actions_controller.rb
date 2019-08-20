# frozen_string_literal: true

class UserActionsController < ApplicationController

  def index
    params.require(:username)
    params.permit(:filter, :offset, :acting_username)

    user = fetch_user_from_params(include_inactive: current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts))
    raise Discourse::NotFound unless guardian.can_see_profile?(user)

    offset = [0, params[:offset].to_i].max
    action_types = (params[:filter] || "").split(",").map(&:to_i)

    opts = {
      user_id: user.id,
      user: user,
      offset: offset,
      limit: 30,
      action_types: action_types,
      guardian: guardian,
      ignore_private_messages: params[:filter] ? false : true,
      acting_username: params[:acting_username]
    }

    stream = UserAction.stream(opts).to_a
    if stream.empty? && (help_key = params['no_results_help_key'])
      if user.id == guardian.user.try(:id)
        help_key += ".self"
      else
        help_key += ".others"
      end
      render json: {
        user_action: [],
        no_results_help: I18n.t(help_key)
      }
    else
      render_serialized(stream, UserActionSerializer, root: 'user_actions')
    end

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
