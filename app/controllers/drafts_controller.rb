# frozen_string_literal: true

class DraftsController < ApplicationController
  requires_login

  skip_before_action :check_xhr, :preload_json

  def index
    params.require(:username)
    params.permit(:offset)
    params.permit(:limit)

    user = fetch_user_from_params

    unless user == current_user
      raise Discourse::InvalidAccess
    end

    opts = {
      user: user,
      offset: params[:offset],
      limit: params[:limit]
    }

    stream = Draft.stream(opts)
    stream.each do |d|
      parsed_data = JSON.parse(d.data)
      if parsed_data
        if parsed_data['reply']
          d.raw = parsed_data['reply']
        end
        if parsed_data['categoryId'].present? && !d.category_id.present?
          d.category_id = parsed_data['categoryId']
        end
      end
    end

    render json: {
      drafts: stream ? serialize_data(stream, DraftSerializer) : [],
      no_results_help: I18n.t("user_activity.no_drafts.self")
    }

  end

end
