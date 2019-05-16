# frozen_string_literal: true

class RenamePostNotices < ActiveRecord::Migration[5.2]
  def up
    add_index :post_custom_fields, :post_id, unique: true, name: "index_post_custom_fields_on_notice_type", where: "name = 'notice_type'"
    add_index :post_custom_fields, :post_id, unique: true, name: "index_post_custom_fields_on_notice_args", where: "name = 'notice_args'"

    # Split site setting `min_post_notice_tl` into `new_user_notice_tl` and `returning_user_notice_tl`.
    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT 'new_user_notice_tl', data_type, value, created_at, updated_at
      FROM site_settings WHERE name = 'min_post_notice_tl'
      UNION
      SELECT 'returning_user_notice_tl', data_type, value, created_at, updated_at
      FROM site_settings WHERE name = 'min_post_notice_tl'
    SQL
    execute "DELETE FROM site_settings WHERE name = 'min_post_notice_tl'"

    # Rename custom fields to match new naming scheme.
    execute "UPDATE post_custom_fields SET name = 'notice_type', value = 'new_user'       WHERE name = 'post_notice_type' AND value = 'first'"
    execute "UPDATE post_custom_fields SET name = 'notice_type', value = 'returning_user' WHERE name = 'post_notice_type' AND value = 'returning'"
    execute "UPDATE post_custom_fields SET name = 'notice_args'                           WHERE name = 'post_notice_time'"

    # Delete all notices for bots, staged and anonymous users.
    execute <<~SQL
      DELETE FROM user_custom_fields
      WHERE (name = 'notice_type' OR name = 'notice_args')
        AND user_id IN (SELECT id FROM users WHERE id <= 0 OR staged = true
                        UNION
                        SELECT user_id FROM user_custom_fields ucf WHERE name = 'master_id')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
