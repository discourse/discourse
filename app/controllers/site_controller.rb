require_dependency 'site_serializer'

class SiteController < ApplicationController
  layout false
  skip_before_filter :preload_json, :check_xhr

  def site
    render json: Site.json_for(guardian)
  end

  def settings
    render json: SiteSetting.client_settings_json
  end

  def custom_html
    render json: custom_html_json
  end

  def banner
    render json: banner_json
  end

  def emoji
    render json: custom_emoji
  end
end
