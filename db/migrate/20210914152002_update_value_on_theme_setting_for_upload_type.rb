# frozen_string_literal: true

class UpdateValueOnThemeSettingForUploadType < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE theme_settings
      SET value = (SELECT id FROM uploads WHERE uploads.url = theme_settings.value)
      WHERE data_type = 6
    SQL
  end

  def down
    execute <<~SQL
      UPDATE theme_settings
      SET value = (SELECT url FROM uploads WHERE uploads.id = theme_settings.value)
      WHERE data_type = 6
    SQL
  end
end
