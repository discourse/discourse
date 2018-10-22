class MigrateS3BackupSiteSettings < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name      = 'backup_location',
          data_type = 7,
          value     = 's3'
      WHERE name = 'enable_s3_backups' AND value = 't';
    SQL

    execute <<~SQL
      DELETE
      FROM site_settings
      WHERE name = 'enable_s3_backups';
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings
      SET name      = 'enable_s3_backups',
          data_type = 5,
          value     = 't'
      WHERE name = 'backup_location' AND value = 's3';
    SQL

    execute <<~SQL
      DELETE
      FROM site_settings
      WHERE name = 'backup_location';
    SQL
  end
end
