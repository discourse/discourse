# frozen_string_literal: true

class AddLocaleToSearchDataPrimaryKeys < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Get default locale from site_settings table, not from application code
    default_locale_result =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'default_locale'")
    default_locale = default_locale_result.first || "en"

    # For post_search_data: change PK from (post_id) to (post_id, locale)
    # Ensure all existing rows have a locale (use site default if null)
    DB.exec(<<~SQL, locale: default_locale)
      UPDATE post_search_data
      SET locale = COALESCE(locale, :locale)
      WHERE locale IS NULL OR locale = '';
    SQL

    execute <<~SQL
      -- Drop the old primary key constraint
      ALTER TABLE post_search_data DROP CONSTRAINT posts_search_pkey;

      -- Make locale NOT NULL now that we've filled in values
      ALTER TABLE post_search_data ALTER COLUMN locale SET NOT NULL;

      -- Set default for future inserts
      ALTER TABLE post_search_data ALTER COLUMN locale SET DEFAULT 'en';

      -- Add new compound primary key
      ALTER TABLE post_search_data ADD PRIMARY KEY (post_id, locale);
    SQL

    # Create GIN index concurrently to avoid table locking
    # Drop first in case of previous failed concurrent index creation
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_search_post_locale;"

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_search_post_locale
        ON post_search_data USING gin(search_data)
        WHERE locale IS NOT NULL;
    SQL

    # For topic_search_data: change PK from (topic_id) to (topic_id, locale)
    # Ensure all existing rows have a locale
    DB.exec(<<~SQL, locale: default_locale)
      UPDATE topic_search_data
      SET locale = COALESCE(locale, :locale)
      WHERE locale IS NULL OR locale = '';
    SQL

    execute <<~SQL
      -- Drop the old primary key constraint
      ALTER TABLE topic_search_data DROP CONSTRAINT topic_search_data_pkey;

      -- Locale should already be NOT NULL, but ensure it
      ALTER TABLE topic_search_data ALTER COLUMN locale SET NOT NULL;

      -- Set default for future inserts
      ALTER TABLE topic_search_data ALTER COLUMN locale SET DEFAULT 'en';

      -- Add new compound primary key
      ALTER TABLE topic_search_data ADD PRIMARY KEY (topic_id, locale);
    SQL

    # Create GIN index concurrently to avoid table locking
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_search_topic_locale;"

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_search_topic_locale
        ON topic_search_data USING gin(search_data)
        WHERE locale IS NOT NULL;
    SQL
  end

  def down
    # WARNING: This rollback permanently deletes all non-default locale search data.
    # All localized search indices will be lost and will need to be regenerated
    # if you re-run the migration.

    # Revert post_search_data
    execute <<~SQL
      -- Keep only the default locale row for each post
      DELETE FROM post_search_data
      WHERE (post_id, locale) NOT IN (
        SELECT post_id, MIN(locale)
        FROM post_search_data
        GROUP BY post_id
      );

      -- Drop compound primary key
      ALTER TABLE post_search_data DROP CONSTRAINT post_search_data_pkey;

      -- Add back single-column primary key
      ALTER TABLE post_search_data ADD PRIMARY KEY (post_id);

      -- Drop the locale-specific index
      DROP INDEX IF EXISTS idx_search_post_locale;

      -- Make locale nullable again
      ALTER TABLE post_search_data ALTER COLUMN locale DROP NOT NULL;
    SQL

    # Revert topic_search_data
    execute <<~SQL
      -- Keep only the default locale row for each topic
      DELETE FROM topic_search_data
      WHERE (topic_id, locale) NOT IN (
        SELECT topic_id, MIN(locale)
        FROM topic_search_data
        GROUP BY topic_id
      );

      -- Drop compound primary key
      ALTER TABLE topic_search_data DROP CONSTRAINT topic_search_data_pkey;

      -- Add back single-column primary key
      ALTER TABLE topic_search_data ADD PRIMARY KEY (topic_id);

      -- Drop the locale-specific index
      DROP INDEX IF EXISTS idx_search_topic_locale;
    SQL
  end
end
