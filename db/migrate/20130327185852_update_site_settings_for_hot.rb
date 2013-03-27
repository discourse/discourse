class UpdateSiteSettingsForHot < ActiveRecord::Migration
  def up
    execute "UPDATE site_settings SET value = REPLACE(value, 'popular|', 'latest|hot|') where name = 'top_menu'"
  end

  def down
    execute "UPDATE site_settings SET value = REPLACE(value, 'latest|hot', 'popular|') where name = 'top_menu'"
  end
end
