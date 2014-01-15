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
    render nothing: true
  end

end
