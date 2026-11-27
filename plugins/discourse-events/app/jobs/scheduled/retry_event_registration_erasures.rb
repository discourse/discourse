# frozen_string_literal: true

module Jobs
  class RetryEventRegistrationErasures < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      field = DiscourseEvents::Events::Registration::REPORT_USER_FIELD
      ids = DB.query_single(<<~SQL, field:, action: UserHistory.actions[:anonymize_user])
        WITH registrants AS (
          SELECT user_id, MIN(created_at) AS first_submission
          FROM discourse_event_registrations GROUP BY user_id
          UNION ALL
          SELECT value::integer, MIN(created_at) FROM post_custom_fields WHERE name = :field GROUP BY value
        )
        SELECT DISTINCT r.user_id FROM registrants r
        WHERE NOT EXISTS (SELECT 1 FROM users WHERE id = r.user_id)
           OR EXISTS (
             SELECT 1 FROM user_histories h
             WHERE h.target_user_id = r.user_id AND h.action = :action AND h.created_at >= r.first_submission
           )
      SQL
      ids.each { |user_id| Jobs.enqueue(:erase_event_registrations, user_id:) }
    end
  end
end
