# frozen_string_literal: true

class RenameAiImageCaptionSiteSettings < ActiveRecord::Migration[8.0]
  def up
    rename_setting("ai_helper_image_caption_agent", "ai_image_caption_agent")
    rename_setting("ai_post_image_descriptions_enabled", "ai_post_image_captions_enabled")
    rename_setting(
      "ai_post_image_descriptions_per_post_limit",
      "ai_post_image_captions_per_post_limit",
    )
    rename_setting(
      "ai_post_image_descriptions_backfill_hourly_rate",
      "ai_post_image_captions_backfill_hourly_rate",
    )
    rename_setting(
      "ai_post_image_descriptions_backfill_max_age_days",
      "ai_post_image_captions_backfill_max_age_days",
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def rename_setting(old_name, new_name)
    old_name = connection.quote(old_name)
    new_name = connection.quote(new_name)

    execute <<~SQL
      DELETE FROM site_settings old_settings
      WHERE old_settings.name = #{old_name}
        AND EXISTS (
          SELECT 1
          FROM site_settings new_settings
          WHERE new_settings.name = #{new_name}
        )
    SQL

    execute <<~SQL
      UPDATE site_settings
      SET name = #{new_name}
      WHERE name = #{old_name}
    SQL
  end
end
