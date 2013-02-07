class Admin::SiteSettingsController < Admin::AdminController

  def index
    @site_settings = SiteSetting.all_settings
    render_json_dump(@site_settings.as_json)
  end

  def update
    requires_parameter(:value)
    SiteSetting.send("#{params[:id]}=", params[:value])
    render nothing: true
  end

end
