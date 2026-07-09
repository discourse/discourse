# frozen_string_literal: true
class RemoveImageCaptionFromAiHelperEnabledFeatures < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET value = (
            SELECT array_to_string(
              ARRAY(
                SELECT feature
                FROM unnest(string_to_array(site_settings.value, '|')) AS feature
                WHERE feature <> 'image_caption'
              ),
              '|'
            )
          ),
          updated_at = NOW()
      WHERE name = 'ai_helper_enabled_features'
        AND 'image_caption' = ANY(string_to_array(value, '|'))
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
