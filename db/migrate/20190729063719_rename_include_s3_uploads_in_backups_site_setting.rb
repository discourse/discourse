# frozen_string_literal: true

class RenameIncludeS3UploadsInBackupsSiteSetting < ActiveRecord::Migration[5.2]
  def up
    execute "UPDATE site_settings SET name = 'include_s3_uploads_in_automatic_backups' WHERE name = 'include_s3_uploads_in_backups'"
  end

  def down
    execute "UPDATE site_settings SET name = 'include_s3_uploads_in_backups' WHERE name = 'include_s3_uploads_in_automatic_backups'"
  end
end
