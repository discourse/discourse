class ManifestJsonController < ApplicationController
  layout false
  skip_before_filter :preload_json, :check_xhr, :redirect_to_login_if_required

  def index
    manifest = {
      short_name: SiteSetting.title,
      display: 'standalone',
      orientation: 'portrait',
      start_url: "#{Discourse.base_uri}/",
      background_color: "##{ColorScheme.hex_for_name('secondary')}",
      theme_color: "##{ColorScheme.hex_for_name('header_background')}"
    }

    render json: manifest.to_json
  end
end
