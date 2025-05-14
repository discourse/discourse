# frozen_string_literal: true

class HomepageHelper
  def self.resolve(request = nil, current_user = nil)
    return "blank" if !current_user && SiteSetting.login_required?

    return "custom" if ThemeModifierHelper.new(request: request).custom_homepage

    enabled = false
    enabled =
      DiscoursePluginRegistry.apply_modifier(
        :custom_homepage_enabled,
        enabled,
        request: request,
        current_user: current_user,
      )
    return "custom" if enabled

    current_user ? SiteSetting.homepage : SiteSetting.anonymous_homepage
  end
end
