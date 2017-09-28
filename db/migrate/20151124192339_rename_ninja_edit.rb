class RenameNinjaEdit < ActiveRecord::Migration[4.2]
  def change
    execute "UPDATE site_settings SET name = 'editing_grace_period' WHERE name = 'ninja_edit_window'"
  end
end
