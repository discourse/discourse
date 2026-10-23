# frozen_string_literal: true
class RemoveVoiceNoiseSuppressionSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'voice_noise_suppression'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
