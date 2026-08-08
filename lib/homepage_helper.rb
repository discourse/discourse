# frozen_string_literal: true

class HomepageHelper
  def self.resolve(request = nil, current_user = nil)
    return "blank" if !current_user && SiteSetting.login_required?

    if ThemeModifierHelper.new(request: request).custom_homepage
      return custom_homepage_route(request)
    end

    enabled =
      DiscoursePluginRegistry.apply_modifier(
        :custom_homepage_enabled,
        false,
        request: request,
        current_user: current_user,
      )

    # current_user ? SiteSetting.homepage : SiteSetting.anonymous_homepage

    # TODO (saquetim) temporarily enabled the homepage route for testing purposed
    #  the plugin needs to provide a proper way of enabling this.
    custom_homepage_route(request)
  end

  def self.custom_homepage_route(request)
    if CrawlerDetection.crawler_layout_request?(request)
      return SiteSetting.custom_homepage_crawler_route
    end

    "custom"
  end
end
