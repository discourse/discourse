# frozen_string_literal: true
class RemoveForceOldReviewableUiSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'force_old_reviewable_ui'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
