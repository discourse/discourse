require_dependency 'site_serializer'

class SiteController < ApplicationController
  layout false
  skip_before_action :preload_json, :check_xhr
  skip_before_action :redirect_to_login_if_required, only: ['basic_info', 'statistics']

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

  def basic_info
    results = {
      logo_url: UrlHelper.absolute(SiteSetting.logo_url),
      logo_small_url: UrlHelper.absolute(SiteSetting.logo_small_url),
      apple_touch_icon_url: UrlHelper.absolute(SiteSetting.apple_touch_icon_url),
      favicon_url:  UrlHelper.absolute(SiteSetting.favicon_url),
      title: SiteSetting.title,
      description: SiteSetting.site_description
    }
    results[:mobile_logo_url] = SiteSetting.mobile_logo_url.presence

    DiscourseHub.stats_fetched_at = Time.zone.now if request.user_agent == "Discourse Hub"

    # this info is always available cause it can be scraped from a 404 page
    render json: results
  end

  def statistics
    return redirect_to path('/') unless SiteSetting.share_anonymized_statistics?
    render json: About.fetch_cached_stats
  end
end
