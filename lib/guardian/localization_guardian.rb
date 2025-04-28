# frozen_string_literal: true

module LocalizationGuardian
  def can_localize_content?
    return false if !SiteSetting.experimental_content_localization
    user.in_any_groups?(SiteSetting.experimental_content_localization_allowed_groups_map)
  end
end
