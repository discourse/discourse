# frozen_string_literal: true

class Themes::Action::HorizonHighContextTopicCardsToggled < Service::ActionBase
  option :enabled

  def call
    theme = Theme.horizon_theme
    return if theme.blank?
    return if theme.settings.blank?

    setting = theme.settings[:topic_card_high_context]
    return if setting.blank? || setting.value == enabled

    theme.update_setting(:topic_card_high_context, enabled)
    theme.save!
  end

  def self.should_display_upcoming_change?
    horizon_theme_available? &&
      # If the theme setting exists, this means this is an existing
      # site that got the legacy migration. If no setting exists,
      # it's a new site which has the theme setting for high-context topic cards
      # enabled by default.
      ThemeSetting.exists?(theme_id: Theme.horizon_theme.id, name: :topic_card_high_context)
  end

  def self.horizon_theme_available?
    horizon_theme = Theme.horizon_theme
    return false if horizon_theme.blank? || !horizon_theme.enabled?
    return false if !horizon_theme.user_selectable? && !horizon_theme.default?
    horizon_theme.default? || horizon_theme.user_selectable?
  end
end
