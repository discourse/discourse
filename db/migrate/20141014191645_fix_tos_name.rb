class FixTosName < ActiveRecord::Migration
  def up
    I18n.overrides_disabled do
      execute ActiveRecord::Base.sql_fragment('UPDATE user_fields SET name = ? WHERE name = ?', I18n.t('terms_of_service.title'), I18n.t("terms_of_service.signup_form_message"))
    end

  end
end
