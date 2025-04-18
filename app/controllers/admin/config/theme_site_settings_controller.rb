# frozen_string_literal: true

class Admin::Config::ThemeSiteSettingsController < Admin::AdminController
  rescue_from Discourse::InvalidParameters do |e|
    render_json_error e.message, status: 422
  end

  def index
    params.permit(:theme_id)

    respond_to do |format|
      format.json do
        render_json_dump(
          ThemeSiteSetting.where(theme_id: params[:theme_id]).as_json(only: %i[id name value]),
        )
      end
    end
  end
end
