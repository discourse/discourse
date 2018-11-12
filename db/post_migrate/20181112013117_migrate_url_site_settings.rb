class MigrateUrlSiteSettings < ActiveRecord::Migration[5.2]
  def up
    old_logo_url = DB.query_single(
      "SELECT value FROM site_settings WHERE name = 'logo_url'"
    ).first

    return if old_logo_url.blank?

    file = FileHelper.download(
      UrlHelper.absolute(old_logo_url),
      max_file_size: 20.megabytes,
      tmp_file_name: 'tmp_site_setting_logo',
      skip_rate_limit: true,
      follow_redirect: true
    )

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

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
