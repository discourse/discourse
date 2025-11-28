# frozen_string_literal: true

class DeleteOldDefaultValues < ActiveRecord::Migration[8.0]
  def up
    delete_setting("cakeday_enabled", migration_timestamp("20250717093505"))
    delete_setting("cakeday_birthday_enabled", migration_timestamp("20250811132217"))
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migration_timestamp(version)
    DB.query_single(<<~SQL, version:).first
      SELECT created_at
      FROM schema_migration_details
      WHERE version = :version
    SQL
  end

  def delete_setting(name, time)
    return if time.nil?

    DB.exec(<<~SQL, name:, time:)
      DELETE FROM site_settings
      WHERE
        name = :name AND
        created_at >= timestamp :time - interval '10 seconds' AND
        created_at <= timestamp :time + interval '10 seconds' AND
        updated_at >= timestamp :time - interval '10 seconds' AND
        updated_at <= timestamp :time + interval '10 seconds'
    SQL
  end
end
