class MetadataController < ApplicationController
  layout false
  skip_before_filter :preload_json, :check_xhr, :redirect_to_login_if_required

  def manifest
    manifest = {
      name: SiteSetting.title,
      short_name: SiteSetting.title,
      display: 'standalone',
      orientation: 'portrait',
      start_url: "#{Discourse.base_uri}/",
      background_color: "##{ColorScheme.hex_for_name('secondary')}",
      theme_color: "##{ColorScheme.hex_for_name('header_background')}",
      icons: [
        {
          src: SiteSetting.apple_touch_icon_url,
          sizes: "144x144",
          type: "image/png"
        }
      ]
    }

    render json: manifest.to_json
  end

  def opensearch
    render file: "#{Rails.root}/app/views/metadata/opensearch.xml"
  end
end
