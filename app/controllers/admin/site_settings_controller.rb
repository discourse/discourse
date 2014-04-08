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
    StaffActionLogger.new(current_user).log_site_setting_change(id, SiteSetting.send(id), value) if SiteSetting.has_setting?(id)
    SiteSetting.set(id, value)
    render nothing: true
  end

end
