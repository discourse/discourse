# frozen_string_literal: true

# TODO: Comment this migration out when merging the plugin into core
class PersistCakedayBirthdayEnabled < ActiveRecord::Migration[8.0]
  def up
    # 5 is bool data_type
    DB.exec(<<~SQL, value: SiteSetting.cakeday_birthday_enabled ? "t" : "f")
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES('cakeday_birthday_enabled', 5, :value, NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
