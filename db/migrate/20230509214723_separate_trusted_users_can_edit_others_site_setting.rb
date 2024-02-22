# frozen_string_literal: true

class SeparateTrustedUsersCanEditOthersSiteSetting < ActiveRecord::Migration[7.0]
  def up
    if select_value(
         "SELECT 1 FROM site_settings WHERE name = 'trusted_users_can_edit_others' AND value = 'f'",
       )
      execute <<~SQL
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('edit_all_topic_groups', 20, '', now(), now());
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('edit_all_post_groups', 20, '', now(), now());
      SQL
    end
  end

  def down
    execute <<~SQL
      DELETE FROM site_settings WHERE name = 'edit_all_topic_groups';
      DELETE FROM site_settings WHERE name = 'edit_all_post_groups';
    SQL
  end
end
