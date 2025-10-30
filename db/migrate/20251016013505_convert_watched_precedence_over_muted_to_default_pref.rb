# frozen_string_literal: true
class ConvertWatchedPrecedenceOverMutedToDefaultPref < ActiveRecord::Migration[8.0]
  def up
    existing_setting_value =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'watched_precedence_over_muted'",
      ).first

    # Data type 5 is boolean
    DB.exec(<<~SQL, setting_value: existing_setting_value) if existing_setting_value
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('default_watched_precedence_over_muted', 5, :setting_value, NOW(), NOW())
      SQL

    preference_value =
      if existing_setting_value.nil?
        # This is the default site setting value for default_watched_precedence_over_muted
        preference_value = false
      else
        preference_value = existing_setting_value == "t"
      end

    DB.exec(<<~SQL, preference_value: preference_value)
      UPDATE user_options
      SET watched_precedence_over_muted = :preference_value
      WHERE watched_precedence_over_muted IS NULL;
    SQL

    change_column_default :user_options, :watched_precedence_over_muted, from: nil, to: false
    change_column_null :user_options, :watched_precedence_over_muted, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
