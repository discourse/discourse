# frozen_string_literal: true

class MigrateTosSetting < ActiveRecord::Migration[4.2]
  def up
    res = execute("SELECT * FROM site_settings WHERE name = 'tos_accept_required' AND value = 't'")
    if res.present? && res.cmd_tuples > 0
      label = "Terms of Service"

      res = execute("SELECT value FROM site_texts WHERE text_type = 'tos_signup_form_message'")
      label = res[0]["value"] if res.present? && res.cmd_tuples == 1

      label = PG::Connection.escape_string(label)
      execute(
        "INSERT INTO user_fields (name, field_type, editable) VALUES ('#{label}', 'confirm', false)",
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
