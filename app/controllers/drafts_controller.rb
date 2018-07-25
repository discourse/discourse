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

    guardian.ensure_can_see_drafts!(user)
    stream = Draft.stream(opts)
    stream.each do |d|
      parsed_data = JSON.parse(d.data) rescue nil
      if parsed_data
        if parsed_data['reply']
          d.raw = parsed_data['reply']
        end
        if parsed_data['categoryId'].present? && !d.category_id.present?
          d.category_id = parsed_data['categoryId']
        end
      end
    end

    help_key = "user_activity.no_drafts"
    if user == current_user
      help_key += ".self"
    else
      help_key += ".others"
    end

    render json: {
      drafts: serialize_data(stream, DraftSerializer),
      no_results_help: I18n.t(help_key)
    }

  end

end
