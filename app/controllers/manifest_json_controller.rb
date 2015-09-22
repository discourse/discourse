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

    if !SiteSetting.gcm_sender_id.blank?
      manifest.merge!({
        gcm_sender_id: SiteSetting.gcm_sender_id,
        gcm_user_visible_only: true # This is required for Chrome 42 up to Chrome 44
      })
    end

    render json: manifest.to_json
  end
end
