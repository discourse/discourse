class Admin::SiteSettingsController < Admin::AdminController

  def index
    site_settings = SiteSetting.all_settings
    info = {site_settings: site_settings, diags: SiteSetting.diags }
    render_json_dump(info.as_json)
  end

  def update
    raise ActionController::ParameterMissing.new(:value) unless params.has_key?(:value)
    StaffActionLogger.new(current_user).log_site_setting_change(params[:id], SiteSetting.send("#{params[:id]}"), params[:value]) if SiteSetting.respond_to?(params[:id])
    SiteSetting.send("#{params[:id]}=", params[:value])
    render nothing: true
  end

end
