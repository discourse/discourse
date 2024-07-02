# frozen_string_literal: true

class RemoveInvalidCspScriptSrcSiteSettingValues < ActiveRecord::Migration[7.0]
  def up
    prev_value =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'content_security_policy_script_src'",
      ).first

    return if prev_value.blank?

    regex =
      /
        (?:\A'unsafe-eval'\z)|
        (?:\A'wasm-unsafe-eval'\z)|
        (?:\A'sha(?:256|384|512)-[A-Za-z0-9+\/\-_]+={0,2}'\z)
      /x
    new_value = prev_value.split("|").select { |substring| substring.match?(regex) }.uniq.join("|")

    return if new_value == prev_value

    DB.exec(<<~SQL, new_value:)
      UPDATE site_settings
      SET value = :new_value
      WHERE name = 'content_security_policy_script_src'
    SQL

    DB.exec(<<~SQL, prev_value:, new_value:)
      INSERT INTO user_histories (action, subject, previous_value, new_value, admin_only, updated_at, created_at, acting_user_id)
      VALUES (3, 'content_security_policy_script_src', :prev_value, :new_value, true, NOW(), NOW(), -1)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
