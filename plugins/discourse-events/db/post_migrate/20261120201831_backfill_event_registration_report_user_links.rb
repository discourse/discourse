# frozen_string_literal: true
class BackfillEventRegistrationReportUserLinks < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO post_custom_fields (post_id, name, value, created_at, updated_at)
      SELECT r.report_post_id, 'event_registration_report_user_id', r.user_id::text, r.created_at, CURRENT_TIMESTAMP
        FROM discourse_event_registrations r
        JOIN posts p ON p.id = r.report_post_id
       WHERE NOT EXISTS (
         SELECT 1 FROM post_custom_fields f
          WHERE f.post_id = r.report_post_id AND f.name = 'event_registration_report_user_id'
       )
       ORDER BY r.id FOR UPDATE OF r
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
