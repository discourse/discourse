# frozen_string_literal: true

class GuessPreviouslySavedSettings < ActiveRecord::Migration[8.0]
  def up
    # new sites should use the new default ("false")
    return if Migration::Helpers.new_site?

    migrate_setting("cakeday_enabled")
    migrate_setting("cakeday_birthday_enabled")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migrate_setting(name)
    # already exists, skip
    return if DB.query_single("SELECT 1 FROM site_settings WHERE name = :name", name:).first

    # if the site ran the old onceoff before the core merge - it had d-cakeday installed
    old_onceoff_timestamp =
      DB.query_single(
        "SELECT created_at FROM onceoff_logs WHERE job_name = :name",
        name: "FixInvalidDateOfBirth",
      ).first
    if old_onceoff_timestamp && old_onceoff_timestamp.before?(core_merge_time)
      create_setting(name, "t")
    end
  end

  def create_setting(name, value)
    # 5 is bool data_type
    DB.exec(<<~SQL, name:, value:)
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES(:name, 5, :value, NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL
  end
end
