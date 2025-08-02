# frozen_string_literal: true

class RenameEnglishLocale < ActiveRecord::Migration[6.0]
  def up
    rename_locale(old: "en", new: "en_GB")
    rename_locale(old: "en_US", new: "en")
  end

  def down
    rename_locale(old: "en", new: "en_US")
    rename_locale(old: "en_GB", new: "en")
  end

  private

  def rename_locale(old:, new:)
    execute <<~SQL
      UPDATE users
      SET locale = '#{new}'
      WHERE locale = '#{old}'
    SQL

    execute <<~SQL
      UPDATE site_settings
      SET value = '#{new}'
      WHERE name = 'default_locale' AND value = '#{old}'
    SQL

    execute <<~SQL
      UPDATE translation_overrides
      SET locale = '#{new}'
      WHERE locale = '#{old}'
    SQL

    execute <<~SQL
      UPDATE theme_translation_overrides
      SET locale = '#{new}'
      WHERE locale = '#{old}'
    SQL
  end
end
