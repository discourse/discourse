# frozen_string_literal: true

class ReplaceVoiceVideoEnabledSetting < ActiveRecord::Migration[8.0]
  GROUP_LIST_DATA_TYPE = 20

  # Camera and screen sharing moved from one site-wide boolean to a group list
  # each, whose defaults grant both to logged-in users. A site that had turned
  # video off has to keep it off, which an unset group list would not do.
  def up
    video_was_off =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'voice_video_enabled'").first ==
        "f"

    if video_was_off
      %w[voice_video_allowed_groups voice_screen_share_allowed_groups].each do |name|
        DB.exec(<<~SQL, name: name, data_type: GROUP_LIST_DATA_TYPE)
          INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
          VALUES (:name, :data_type, '', NOW(), NOW())
          ON CONFLICT (name) DO NOTHING
        SQL
      end
    end

    execute "DELETE FROM site_settings WHERE name = 'voice_video_enabled'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
