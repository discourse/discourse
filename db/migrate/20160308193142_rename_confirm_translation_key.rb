class RenameConfirmTranslationKey < ActiveRecord::Migration[4.2]
  def change
    execute "UPDATE translation_overrides SET translation_key = 'user_notifications.confirm_new_email.subject_template'
               WHERE translation_key = 'user_notifications.authorize_email.subject_template'"
    execute "UPDATE translation_overrides SET translation_key = 'user_notifications.confirm_new_email.text_body_template'
               WHERE translation_key = 'user_notifications.authorize_email.text_body_template'"
  end
end
