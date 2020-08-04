# frozen_string_literal: true

class AddPublicFieldToPublishedPages < ActiveRecord::Migration[6.0]
  def up
    # Delete the record of https://github.com/discourse/discourse/commit/b9762afc106ee9b18d1ac33ca3cac281083e428e
    execute <<~SQL
      DELETE FROM schema_migrations WHERE version='20201006172700'
    SQL

    # Delete the reference to the incorrectly versioned version of this migration
    execute <<~SQL
      DELETE FROM schema_migrations WHERE version='20201006172701'
    SQL

    # Using IF NOT EXISTS because the version number of this migration was changed
    # Therefore some sites may have already added the column
    execute <<~SQL
      ALTER TABLE "published_pages" ADD COLUMN IF NOT EXISTS "public" boolean DEFAULT FALSE NOT NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
