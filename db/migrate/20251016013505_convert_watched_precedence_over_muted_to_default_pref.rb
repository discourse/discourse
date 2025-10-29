# frozen_string_literal: true
class ConvertWatchedPrecedenceOverMutedToDefaultPref < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE site_settings SET name = 'default_watched_precedence_over_muted'
      WHERE name = 'watched_precedence_over_muted';
    SQL

    existing_setting_value =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'default_watched_precedence_over_muted'",
      ).first

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
