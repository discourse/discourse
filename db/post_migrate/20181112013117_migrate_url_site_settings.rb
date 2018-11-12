class MigrateUrlSiteSettings < ActiveRecord::Migration[5.2]
  def up
    [
      'logo_url',
      'logo_small_url',
      'digest_logo_url',
      'mobile_logo_url',
      'large_icon_url'
    ].each do |url_site_setting|
      old_logo_url = DB.query_single(
        "SELECT value FROM site_settings WHERE name = '#{url_site_setting}'"
      ).first

      next if old_logo_url.blank?

      file = FileHelper.download(
        UrlHelper.absolute(old_logo_url),
        max_file_size: 20.megabytes,
        tmp_file_name: 'tmp_site_setting_logo',
        skip_rate_limit: true,
        follow_redirect: true
      )

      next if file.blank?

      upload = UploadCreator.new(
        file,
        'site_setting_logo',
        origin: UrlHelper.absolute(old_logo_url)
      ).create_for(Discourse.system_user.id)

      execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('logo', 18, #{upload.id}, now(), now())
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
