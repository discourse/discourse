class Admin::SiteSettingsController < Admin::AdminController

  def index
    render_json_dump(site_settings: SiteSetting.all_settings, diags: SiteSetting.diags)
  end

  def update
    params.require(:id)
    id = params[:id]
    value = params[id]
    value.strip! if value.is_a?(String)
    begin
      # note, as of Ruby 2.3 symbols are GC'd so this is considered safe
      if SiteSetting.hidden_settings.include?(id.to_sym)
        raise Discourse::InvalidParameters, "You are not allowed to change hidden settings"
      end
      SiteSetting.set_and_log(id, value, current_user)
      render nothing: true
    rescue Discourse::InvalidParameters => e
      render json: {errors: [e.message]}, status: 422
    end
  end

end
