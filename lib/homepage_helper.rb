# frozen_string_literal: true

class HomepageHelper
  def self.resolve(request = nil, current_user = nil)
    return "custom" if ThemeModifierHelper.new(request: request).custom_homepage

    current_user ? SiteSetting.homepage : SiteSetting.anonymous_homepage
  end
end
