# frozen_string_literal: true

class MigrateEnglishLocale < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      UPDATE users
      SET locale = 'en_US'
      WHERE locale = 'en'
    SQL

    execute <<~SQL
      UPDATE site_settings
      SET value = 'en_US'
      WHERE name = 'default_locale' AND value = 'en'
    SQL

    execute <<~SQL
      UPDATE translation_overrides
      SET locale = 'en_US'
      WHERE locale = 'en'
    SQL

    execute <<~SQL
      UPDATE theme_translation_overrides
      SET locale = 'en_US'
      WHERE locale = 'en'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE users
      SET locale = 'en'
      WHERE locale = 'en_US'
    SQL

    execute <<~SQL
      UPDATE site_settings
      SET value = 'en'
      WHERE name = 'default_locale' AND value = 'en_US'
    SQL

    execute <<~SQL
      UPDATE translation_overrides
      SET locale = 'en'
      WHERE locale = 'en_US'
    SQL

    execute <<~SQL
      UPDATE theme_translation_overrides
      SET locale = 'en'
      WHERE locale = 'en_US'
    SQL
  end
end
