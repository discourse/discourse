# frozen_string_literal: true

module DiscourseGifsMigrationFixture
  def add_overrides(theme, overrides)
    overrides.each { |name, value| theme.update_setting(name, value) }
    theme.save!
    theme.reload
  end

  def run_migration(theme, enable_gifs: false)
    expect { DiscourseGifsMigration.migrate_component(theme, enable_gifs:) }.to output.to_stdout
  end

  def add_translation_override(theme, key, value, locale: "en")
    ThemeTranslationOverride.create!(theme:, locale:, translation_key: key, value:)
  end
end
