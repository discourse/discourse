# frozen_string_literal: true

class RemoveBounceScoreThresholdDeactivateSiteSetting < ActiveRecord::Migration[6.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'bounce_score_threshold_deactivate'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
