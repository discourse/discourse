class RenameNinjaEdit < ActiveRecord::Migration
  def change
    execute "UPDATE site_settings SET name = 'editing_grace_period' WHERE name = 'ninja_edit_window'"
  end
end
