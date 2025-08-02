# frozen_string_literal: true

class RemovePollingSiteSettings < ActiveRecord::Migration[6.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_long_polling'"
    execute "DELETE FROM site_settings WHERE name = 'long_polling_interval'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
