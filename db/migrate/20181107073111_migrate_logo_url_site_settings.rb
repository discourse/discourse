class MigrateLogoUrlSiteSettings < ActiveRecord::Migration[5.2]
  FUNCTION_NAME = 'raise_site_settings_logo_url_readonly()'

  def up
    old_logo_url = DB.query_single(
      "SELECT value FROM site_settings WHERE name = 'logo_url'"
    ).first

    return unless old_logo_url

    DB.exec <<~SQL
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME} RETURNS trigger AS $rcr$
        BEGIN
          RAISE EXCEPTION 'Discourse: site_settings with name "logo_url" is readonly';
        END
      $rcr$ LANGUAGE plpgsql;
    SQL

    DB.exec <<~SQL
      CREATE TRIGGER raise_site_settings_logo_url_readonly
      BEFORE INSERT OR UPDATE OF value
      ON site_settings
      FOR EACH ROW
      WHEN (NEW.name IS NOT NULL AND NEW.name = 'logo_url')
      EXECUTE PROCEDURE #{FUNCTION_NAME};
    SQL

    file = FileHelper.download(
      UrlHelper.absolute(old_logo_url),
      max_file_size: 20.megabytes,
      tmp_file_name: 'tmp_site_setting_logo',
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
    DB.exec <<~SQL
    DROP FUNCTION IF EXISTS #{FUNCTION_NAME} CASCADE;
    SQL
  end
end
