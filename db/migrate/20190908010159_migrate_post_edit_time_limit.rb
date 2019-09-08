class MigratePostEditTimeLimit < ActiveRecord::Migration[5.2]
  def up
    tl0_setting = SiteSetting.post_edit_time_limit.to_i
    tl2_setting = SiteSetting.tl2_post_edit_time_limit.to_i

    if tl0_setting > tl2_setting
      execute <<~SQL
        DELETE
        FROM site_settings
        WHERE name = 'post_edit_time_limit';
      SQL

      execute <<~SQL
        DELETE
        FROM site_settings
        WHERE name = 'tl2_post_edit_time_limit';
      SQL

      execute <<~SQL
        INSERT INTO site_settings (
          name,
          data_type,
          value,
          created_at,
          updated_at
        ) VALUES (
          'tl2_post_edit_time_limit',
          3,
          '#{tl0_setting}',
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
      SQL
    end
  end
end
