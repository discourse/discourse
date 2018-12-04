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

  def selectable_avatars
    avatars = if SiteSetting.selectable_avatars_enabled?
      (SiteSetting.selectable_avatars.presence || "").split("\n")
    else
      []
    end

    render json: avatars, root: false
  end

  def basic_info
    results = {
      logo_url: UrlHelper.absolute(SiteSetting.site_logo_url),
      logo_small_url: UrlHelper.absolute(SiteSetting.site_logo_small_url),
      apple_touch_icon_url: UrlHelper.absolute(SiteSetting.site_apple_touch_icon_url),
      favicon_url: UrlHelper.absolute(SiteSetting.site_favicon_url),
      title: SiteSetting.title,
      description: SiteSetting.site_description,
      header_primary_color: ColorScheme.hex_for_name('header_primary') || '333333',
      header_background_color: ColorScheme.hex_for_name('header_background') || 'ffffff'
    }

    if mobile_logo_url = SiteSetting.site_mobile_logo_url.presence
      results[:mobile_logo_url] = UrlHelper.absolute(mobile_logo_url)
    end

    DiscourseHub.stats_fetched_at = Time.zone.now if request.user_agent == "Discourse Hub"

    # this info is always available cause it can be scraped from a 404 page
    render json: results
  end

  def statistics
    return redirect_to path('/') unless SiteSetting.share_anonymized_statistics?
    render json: About.fetch_cached_stats
  end
end
