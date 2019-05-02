# frozen_string_literal: true

class SiteSettingCommaToPipe < ActiveRecord::Migration[4.2]
  def up
    execute <<SQL
      UPDATE site_settings
      SET value = replace(value, ',', '|')
      WHERE name = 'white_listed_spam_host_domains'
      ;
SQL
    execute <<SQL
      UPDATE site_settings
      SET value = replace(value, ',', '|')
      WHERE name = 'exclude_rel_nofollow_domains'
      ;
SQL
  end

  def down
    execute <<SQL
      UPDATE site_settings
      SET value = replace(value, '|', ',')
      WHERE name = 'white_listed_spam_host_domains'
      ;
SQL
    execute <<SQL
      UPDATE site_settings
      SET value = replace(value, '|', ',')
      WHERE name = 'exclude_rel_nofollow_domains'
      ;
SQL
  end
end
