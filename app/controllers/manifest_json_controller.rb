class ManifestJsonController < ApplicationController
  layout false
  skip_before_filter :preload_json, :check_xhr

  def index
    manifest = {
      short_name: SiteSetting.title,
      display: 'browser',
      orientation: 'portrait',
      start_url: "#{Discourse.base_uri}/"
    }

    render json: manifest.to_json
  end
end
