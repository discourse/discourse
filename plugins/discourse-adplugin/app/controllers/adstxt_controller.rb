# frozen_string_literal: true

class AdstxtController < ::ApplicationController
  requires_plugin AdPlugin::PLUGIN_NAME

  skip_before_action :preload_json, :check_xhr, :redirect_to_login_if_required

  def index
    raise Discourse::NotFound if SiteSetting.ads_txt.blank?

    render plain: SiteSetting.ads_txt
  end
end
