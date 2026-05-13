# frozen_string_literal: true

class Themes::Action::HorizonHighContextTopicCardsToggled < Service::ActionBase
  option :enabled

  def call
    theme = Theme.find_by(id: Theme::CORE_THEMES["horizon"])
    return if theme.blank?
    return if theme.settings.blank?

    setting = theme.settings[:topic_card_high_context]
    return if setting.blank? || setting.value == enabled

    theme.set_field(target: :settings, name: :topic_card_high_context, value: enabled)
    theme.save!
  end

  # If the theme setting exists, this means this is an existing
  # site that got the legacy migration. If no setting exists,
  # it's a new site which has the theme setting for high-context topic cards
  # enabled by default.
  def self.should_display_upcoming_change?
    horizon_theme_available? &&
      ThemeSetting.exists?(theme_id: Theme::CORE_THEMES["horizon"], name: :topic_card_high_context)
  end

  def self.horizon_theme_available?
    Theme.user_selectable.where(id: Theme::CORE_THEMES["horizon"], enabled: true).exists?
  end
end
