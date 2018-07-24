class DraftsController < ApplicationController
  requires_login

  skip_before_action :check_xhr, :preload_json

  def index
    params.require(:username)
    params.permit(:offset)
    per_chunk = 30

    user = fetch_user_from_params

    opts = { user_id: user.id,
             user: user,
             offset: params[:offset].to_i,
             limit: per_chunk }

    guardian.ensure_can_see_drafts!(user)

    stream = Draft.stream(opts)

    stream.each do |d|
      parsedData = JSON.parse(d.data)
      d.raw = parsedData['reply']
      if parsedData['categoryId'].present? && !d.category_id.present?
        d.category_id = parsedData['categoryId']
      end
    end

    stream = stream.to_a

    if stream.length == 0
      help_key = "user_activity.no_drafts"
      if user.id == guardian.user.try(:id)
        help_key += ".self"
      else
        help_key += ".others"
      end

      render json: {
        drafts: [],
        no_results_help: I18n.t(help_key)
      }
    else
      render_serialized(stream, DraftSerializer, root: 'drafts')
    end
  end

end
