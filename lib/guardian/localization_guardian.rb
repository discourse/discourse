# frozen_string_literal: true

module LocalizationGuardian
  def can_localize_content?
    return false if !SiteSetting.content_localization_enabled
    user.in_any_groups?(SiteSetting.content_localization_allowed_groups_map)
  end
end
