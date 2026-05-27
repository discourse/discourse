# frozen_string_literal: true

class SplitTranslationPublicContentSetting < ActiveRecord::Migration[7.2]
  def up
    limit_to_public =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'ai_translation_backfill_limit_to_public_content' LIMIT 1",
      ).first

    enabled =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'ai_translation_enabled' LIMIT 1",
      ).first

    if limit_to_public == "f"
      all_category_ids = DB.query_single("SELECT id FROM categories")
      execute <<~SQL if all_category_ids.present?
          INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
          VALUES ('ai_translation_target_categories', 20, '#{all_category_ids.join("|")}', NOW(), NOW())
        SQL

      execute <<~SQL
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('ai_translation_personal_messages', 7, 'all', NOW(), NOW())
      SQL
    elsif enabled == "t"
      public_category_ids =
        DB.query_single("SELECT id FROM categories WHERE read_restricted = false")
      execute <<~SQL if public_category_ids.present?
          INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
          VALUES ('ai_translation_target_categories', 20, '#{public_category_ids.join("|")}', NOW(), NOW())
        SQL
    end

    execute <<~SQL
      DELETE FROM site_settings WHERE name = 'ai_translation_backfill_limit_to_public_content'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
