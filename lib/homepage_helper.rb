# frozen_string_literal: true

class HomepageHelper
  AVAILABILITY_CACHE_KEY = "discourse.homepage_availability"

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

    return custom_homepage_route(request) if enabled

    homepage = current_user ? SiteSetting.homepage : SiteSetting.anonymous_homepage
    return homepage if option_available?(homepage, request, current_user)

    top_menu_homepage(current_user)
  end

  def self.custom_homepage_route(request)
    if CrawlerDetection.crawler_layout_request?(request)
      return SiteSetting.custom_homepage_crawler_route
    end

    "custom"
  end

  def self.option_available?(homepage, request, current_user)
    option = DiscoursePluginRegistry.homepage_options.find { |o| o[:id] == homepage }
    return true if option.nil? || option[:available].nil?

    check = -> do
      !!option[:available].call(guardian: Guardian.new(current_user, request), request: request)
    rescue StandardError => e
      # Every page load resolves the homepage, so a failing check must not
      # take the site down with it.
      Discourse.warn_exception(e, message: "Homepage availability check failed for '#{homepage}'")
      false
    end
    return check.call if request.nil?

    # Resolving `/` evaluates every homepage route constraint, and the layout
    # resolves again, so the check would otherwise run many times per request.
    cache = (request.env[AVAILABILITY_CACHE_KEY] ||= {})
    key = [homepage, current_user&.id]
    cache.key?(key) ? cache[key] : (cache[key] = check.call)
  end

  def self.top_menu_homepage(current_user)
    names = SiteSetting.top_menu_items.map(&:name)
    return names.first if current_user

    names.find { |name| SiteSetting.anonymous_menu_items.include?(name) }
  end

  private_class_method :option_available?, :top_menu_homepage
end
