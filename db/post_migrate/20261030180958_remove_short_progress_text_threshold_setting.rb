# frozen_string_literal: true
class RemoveShortProgressTextThresholdSetting < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'short_progress_text_threshold'"
    execute "DELETE FROM site_setting_groups WHERE name = 'short_progress_text_threshold'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
