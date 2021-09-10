# frozen_string_literal: true

class DraftsController < ApplicationController
  requires_login

  skip_before_action :check_xhr, :preload_json

  def index
    params.require(:username)
    params.permit(:offset)
    params.permit(:limit)

    user = fetch_user_from_params
    raise Discourse::InvalidAccess unless user == current_user

    stream = Draft.stream(
      user: user,
      offset: params[:offset],
      limit: params[:limit]
    )

    render json: {
      drafts: stream ? serialize_data(stream, DraftSerializer) : [],
      no_results_help: I18n.t("user_activity.no_drafts.self")
    }
  end
end
