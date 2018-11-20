class ReplaceBlockedSilenceTranslation < ActiveRecord::Migration[5.1]
  def change
    execute <<~SQL
      UPDATE translation_overrides
      SET translation_key = 'system_messages.silenced_by_staff.subject_template'
      WHERE translation_key = 'system_messages.blocked_by_staff.subject_template'
      AND NOT EXISTS (SELECT 1 FROM translation_overrides WHERE translation_key = 'system_messages.silenced_by_staff.subject_template');
    SQL

    execute <<~SQL
      UPDATE translation_overrides
      SET translation_key = 'system_messages.silenced_by_staff.text_body_template'
      WHERE translation_key = 'system_messages.blocked_by_staff.text_body_template'
      AND NOT EXISTS (SELECT 1 FROM translation_overrides WHERE translation_key = 'system_messages.silenced_by_staff.text_body_template');
    SQL
  end
end
