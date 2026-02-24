# frozen_string_literal: true

class DeprecateReviewableUiRefresh < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'reviewable_ui_refresh'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
