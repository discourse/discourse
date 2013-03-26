class Admin::SiteSettingsController < Admin::AdminController

  def index
    settings = {
      restart_required: Discourse.restart_required?,
      settings: SiteSetting.all_settings,
    }
    render_json_dump(settings.as_json)
  end

  def update
    requires_parameter(:value)
    SiteSetting.send("#{params[:id]}=", params[:value])
    render nothing: true
  end

end
