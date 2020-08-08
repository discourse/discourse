# frozen_string_literal: true

class ChangeSelectableAvatarsSiteSetting < ActiveRecord::Migration[6.0]
  def up
    selectable_avatars = execute("SELECT value FROM site_settings WHERE name = 'selectable_avatars'")
    return if selectable_avatars.cmd_tuples == 0

    # Keep old site setting value as a backup
    execute <<~SQL
      UPDATE site_settings
      SET name = 'selectable_avatars_urls'
      WHERE name = 'selectable_avatars'
    SQL

    # Extract SHA1s from URLs and then use them for upload ID lookups.
    urls = []
    sha1s = []
    selectable_avatars.first["value"].split("\n").each do |url|
      match = url.match(/(\/original\/\dX[\/\.\w]*\/(\h+)[\.\w]*)/)
      if match.present?
        urls << match[1]
        sha1s << match[2]
      else
        STDERR.puts "Could not extract a SHA1 from #{url}"
      end
    end

    upload_ids = execute <<~SQL
      SELECT id
      FROM uploads
      WHERE url IN (#{urls.map { |url| "'#{url}'" }.join(',')})
         OR sha1 IN (#{sha1s.map { |sha1| "'#{sha1}'" }.join(',')})
    SQL
    upload_ids = upload_ids.map { |row| row["id"] }
    return if upload_ids.size == 0

    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT 'selectable_avatars', data_type, '#{upload_ids.join("|")}', created_at, NOW()
      FROM site_settings
      WHERE name = 'selectable_avatars_urls'
    SQL
  end

  def down
    execute("DELETE FROM site_settings WHERE name = 'selectable_avatars'")
    execute("UPDATE site_settings SET name = 'selectable_avatars' WHERE name = 'selectable_avatars_urls'")
  end
end
