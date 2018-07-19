class DraftsController < ApplicationController
  requires_login

  skip_before_action :check_xhr, :preload_json

  def index
    params.require(:username)
    params.permit(:offset)
    per_chunk = 30

    user = fetch_user_from_params(include_inactive: current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts))

    opts = { user_id: user.id,
             user: user,
             offset: params[:offset].to_i,
             limit: per_chunk }

    stream = Draft.stream(opts)
    stream = stream.to_a
    if stream.length == 0
      render json: {
        drafts: [],
        no_results_help: I18n.t('help_key_drafts_empty')
      }
    else
      render_serialized(stream, DraftSerializer, root: 'drafts')
    end
  end

end
