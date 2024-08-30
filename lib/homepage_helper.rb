# frozen_string_literal: true

class HomepageHelper
  def self.resolve(request = nil, current_user = nil)
    return "custom" if ThemeModifierHelper.new(request: request).custom_homepage

    homepage = false
    homepage =
      DiscoursePluginRegistry.apply_modifier(
        :custom_homepage,
        homepage,
        request: request,
        current_user: current_user,
      )
    return "custom" if homepage

    current_user ? SiteSetting.homepage : SiteSetting.anonymous_homepage
  end
end
