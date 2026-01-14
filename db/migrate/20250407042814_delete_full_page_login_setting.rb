# frozen_string_literal: true
class DeleteFullPageLoginSetting < ActiveRecord::Migration[7.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'full_page_login'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
