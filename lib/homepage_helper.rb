# frozen_string_literal: true

class HomepageHelper
  def self.resolve(theme_id = nil, current_user = nil)
    return "custom" if ThemeModifierHelper.new(theme_ids: theme_id).custom_homepage

    current_user ? SiteSetting.homepage : SiteSetting.anonymous_homepage
  end
end
