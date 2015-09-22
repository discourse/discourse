class MigrateSiteTextToSiteCustomization < ActiveRecord::Migration

  def up
    execute <<-SQL
      DO
      $do$
      BEGIN
        IF EXISTS(SELECT 1 FROM site_texts WHERE (text_type = 'head' OR text_type = 'bottom')) THEN
          INSERT INTO site_customizations (name, user_id, enabled, key, created_at, updated_at, head_tag, body_tag)
          VALUES
          (
            'Migrated from Site Text',
            -1,
            't',
            '#{SecureRandom.uuid}',
            now(),
            now(),
            (SELECT value FROM site_texts WHERE text_type = 'head' LIMIT 1),
            (SELECT value FROM site_texts WHERE text_type = 'bottom' LIMIT 1)
          );
        END IF;
      END
      $do$
    SQL
  end

  def down
  end

end
