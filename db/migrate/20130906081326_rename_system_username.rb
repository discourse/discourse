class RenameSystemUsername < ActiveRecord::Migration
  def up
    execute "update site_settings set name = 'site_contact_username' where name = 'system_username'"
  end

  def down
    execute "update site_settings set name = 'system_username' where name = 'site_contact_username'"
  end
end
