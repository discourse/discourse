# frozen_string_literal: true

class DeleteConfirmOldEmailTemplateOverrides < ActiveRecord::Migration[5.1]
  def up
    execute "DELETE FROM translation_overrides WHERE translation_key = 'user_notifications.confirm_old_email.title'"
    execute "DELETE FROM translation_overrides WHERE translation_key = 'user_notifications.confirm_old_email.subject_template'"
    execute "DELETE FROM translation_overrides WHERE translation_key = 'user_notifications.confirm_old_email.text_body_template'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
