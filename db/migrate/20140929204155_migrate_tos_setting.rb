class MigrateTosSetting < ActiveRecord::Migration
  def up
    res = execute("SELECT * FROM site_settings WHERE name = 'tos_accept_required' AND value = 't'")
    if res.present? && res.cmd_tuples > 0
      label = nil

      I18n.overrides_disabled do
        label = I18n.t("terms_of_service.signup_form_message")
      end

      res = execute("SELECT value FROM site_texts WHERE text_type = 'tos_signup_form_message'")
      if res.present? && res.cmd_tuples == 1
        label = res[0]['value']
      end


      label = PG::Connection.escape_string(label)
      execute("INSERT INTO user_fields (name, field_type, editable) VALUES ('#{label}', 'confirm', false)")
    end
  end
end
