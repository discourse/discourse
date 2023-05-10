# frozen_string_literal: true

class SeparateTrustedUsersCanEditOthersSetting < ActiveRecord::Migration[7.0]
  def up
    execute "
    DO
    $do$
    BEGIN
      IF EXISTS (SELECT * FROM site_settings WHERE name = 'trusted_users_can_edit_others') THEN
        DELETE FROM site_settings WHERE name = 'trusted_users_can_edit_others';
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('edit_all_topic_groups', 20, '', now(), now());
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('edit_all_post_groups', 20, '', now(), now());
      END IF;
    END
    $do$
    "
  end

  def down
    execute "
    DO
    $do$
    BEGIN
      IF EXISTS (SELECT * FROM site_settings WHERE name IN ('edit_all_topic_groups','edit_all_post_groups')) THEN
        DELETE FROM site_settings WHERE name = 'edit_all_topic_groups';
        DELETE FROM site_settings WHERE name = 'edit_all_post_groups';
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('trusted_users_can_edit_others', 5, 'f', now(), now());
      END IF;
    END
    $do$
    "
  end
end
