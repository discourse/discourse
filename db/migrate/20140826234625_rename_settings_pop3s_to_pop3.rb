class RenameSettingsPop3sToPop3 < ActiveRecord::Migration
  def up
    execute "UPDATE site_settings SET name = replace(name, 'pop3s', 'pop3') WHERE name ILIKE 'pop3%'"
  end

  def down
    execute "UPDATE site_settings SET name = replace(name, 'pop3', 'pop3s') WHERE name ILIKE 'pop3%'"
  end
end
