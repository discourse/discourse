# frozen_string_literal: true

class ThemeTranslationUpdater
  def self.assign(guardian, theme, translations)
    guardian.ensure_can_edit_theme!(theme)
    available = theme.translations.map(&:key)
    raise Discourse::NotFound if (translations.keys.map(&:to_s) - available).present?
    ThemeTranslationOverride.transaction do
      translations.each_pair { |key, value| theme.update_translation(key, value) }
    end
  end
end
