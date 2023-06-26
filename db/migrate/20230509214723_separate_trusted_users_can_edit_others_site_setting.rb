# frozen_string_literal: true

class SeparateTrustedUsersCanEditOthersSiteSetting < ActiveRecord::Migration[7.0]
  def up
    if select_value(
         "SELECT 1 FROM site_settings WHERE name = 'trusted_users_can_edit_others' AND value = 'f'",
       )
      execute <<~SQL
        DELETE FROM site_settings WHERE name = 'trusted_users_can_edit_others';
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('edit_all_topic_groups', 20, '', now(), now());
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('edit_all_post_groups', 20, '', now(), now());
      SQL
    end
  end

  def down
    if select_value(
         "SELECT 1 FROM site_settings WHERE name IN ('edit_all_topic_groups', 'edit_all_post_groups')",
       )
      execute <<~SQL
        DELETE FROM site_settings WHERE name = 'edit_all_topic_groups';
        DELETE FROM site_settings WHERE name = 'edit_all_post_groups';
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('trusted_users_can_edit_others', 5, 'f', now(), now());
      SQL
    end
  end
end
