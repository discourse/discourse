# frozen_string_literal: true

class ChangeFullNameRequiredSetting < ActiveRecord::Migration[7.2]
  def up
    old_setting = DB.query_single(<<~SQL).first
      SELECT value
      FROM site_settings
      WHERE name = 'full_name_required'
    SQL

    new_setting = nil
    if old_setting
      new_setting = old_setting == "t" ? "required_at_signup" : "optional_at_signup"
    elsif Migration::Helpers.existing_site?
      new_setting = "optional_at_signup"
    end

    DB.exec(<<~SQL)
      DELETE FROM site_settings WHERE name = 'full_name_required'
    SQL

    DB.exec(<<~SQL, value: new_setting) if new_setting
        INSERT INTO site_settings
        (name, data_type, value, created_at, updated_at)
        VALUES
        ('full_name_requirement', 7, :value, NOW(), NOW())
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
