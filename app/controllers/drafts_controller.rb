class DraftsController < ApplicationController
  requires_login

  skip_before_action :check_xhr, :preload_json

  def index
    params.require(:username)
    params.permit(:offset)
    params.permit(:limit)

    user = fetch_user_from_params

    opts = {
      user: user,
      offset: params[:offset],
      limit: params[:limit]
    }

    if user == current_user
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
    else
      raise Discourse::InvalidAccess
    end

    render json: {
      drafts: stream ? serialize_data(stream, DraftSerializer) : [],
      no_results_help: I18n.t("user_activity.no_drafts.self")
    }

  end

end
