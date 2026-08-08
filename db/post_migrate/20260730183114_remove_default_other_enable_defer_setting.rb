# frozen_string_literal: true
class RemoveDefaultOtherEnableDeferSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'default_other_enable_defer'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
