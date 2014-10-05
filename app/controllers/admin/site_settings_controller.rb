class Admin::SiteSettingsController < Admin::AdminController

  def index
    site_settings = SiteSetting.all_settings
    info = {site_settings: site_settings, diags: SiteSetting.diags }
    render_json_dump(info.as_json)
  end

  def update
    params.require(:id)
    id = params[:id]
    value = params[id]
    value.strip! if value.is_a?(String)
    begin
      prev_value = SiteSetting.send(id)
      SiteSetting.set(id, value)
      StaffActionLogger.new(current_user).log_site_setting_change(id, prev_value, value) if SiteSetting.has_setting?(id)
      render nothing: true
    rescue Discourse::InvalidParameters => e
      render json: {errors: [e.message]}, status: 422
    end
  end

end
