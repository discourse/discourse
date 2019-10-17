# frozen_string_literal: true

class MigrateDecompressedFileMaxSizeMb < ActiveRecord::Migration[6.0]
  def up
    current_value = DB.query_single("SELECT value FROM site_settings WHERE name ='decompressed_file_max_size_mb' ").first

    if current_value && current_value != '1000'
      DB.exec <<~SQL
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES
          ('decompressed_theme_max_file_size_mb', 3, #{current_value}, current_timestamp, current_timestamp),
          ('decompressed_backup_max_file_size_mb', 3, #{current_value}, current_timestamp, current_timestamp)
      SQL
    end
  end

  def down
  end
end
