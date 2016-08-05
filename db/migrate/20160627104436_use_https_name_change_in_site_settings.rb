class UseHttpsNameChangeInSiteSettings < ActiveRecord::Migration
  def up
    execute "UPDATE site_settings SET name = 'force_https' WHERE name = 'use_https'"
  end
end
