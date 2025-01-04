# frozen_string_literal: true

class SiteController < ApplicationController
  layout false
  skip_before_action :check_xhr
  skip_before_action :redirect_to_login_if_required,
                     :redirect_to_profile_if_required,
                     only: %w[basic_info statistics]

  def basic_info
    results = {
      logo_url: UrlHelper.absolute(SiteSetting.site_logo_url),
      logo_small_url: UrlHelper.absolute(SiteSetting.site_logo_small_url),
      apple_touch_icon_url: UrlHelper.absolute(SiteSetting.site_apple_touch_icon_url),
      favicon_url: UrlHelper.absolute(SiteSetting.site_favicon_url),
      title: SiteSetting.title,
      description: SiteSetting.site_description,
      header_primary_color: ColorScheme.hex_for_name("header_primary") || "333333",
      header_background_color: ColorScheme.hex_for_name("header_background") || "ffffff",
      login_required: SiteSetting.login_required,
      locale: SiteSetting.default_locale,
      include_in_discourse_discover: SiteSetting.include_in_discourse_discover,
    }

    if mobile_logo_url = SiteSetting.site_mobile_logo_url.presence
      results[:mobile_logo_url] = UrlHelper.absolute(mobile_logo_url)
    end

    # this info is always available cause it can be scraped from a 404 page
    render json: results
  end

  def statistics
    return redirect_to path("/") unless SiteSetting.share_anonymized_statistics?
    render json: About.fetch_cached_stats
  end
end
