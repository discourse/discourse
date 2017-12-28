class ReplaceBlockedSilenceTranslation < ActiveRecord::Migration[5.1]
  def change
    execute <<~SQL
      UPDATE translation_overrides SET translation_key = 'system_messages.silenced_by_staff.subject_template' WHERE translation_key = 'system_messages.blocked_by_staff.subject_template';
      UPDATE translation_overrides SET translation_key = 'system_messages.silenced_by_staff.text_body_template' WHERE translation_key = 'system_messages.blocked_by_staff.text_body_template';
    SQL
  end
end
