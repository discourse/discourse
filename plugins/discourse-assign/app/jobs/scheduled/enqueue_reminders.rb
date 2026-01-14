# frozen_string_literal: true

module Jobs
  class EnqueueReminders < ::Jobs::Scheduled
    REMINDER_BUFFER_MINUTES = 120

    every 1.day

    def execute(_args)
      return if skip_enqueue?
      user_ids.each { |id| Jobs.enqueue(:remind_user, user_id: id) }
    end

    private

    def skip_enqueue?
      SiteSetting.remind_assigns_frequency.nil? || !SiteSetting.assign_enabled? ||
        SiteSetting.assign_allowed_on_groups.blank?
    end

    def allowed_group_ids
      Group.assign_allowed_groups.pluck(:id).join(",")
    end

    def reminder_threshold
      @reminder_threshold ||= SiteSetting.pending_assign_reminder_threshold
    end

    def user_ids
      global_frequency = SiteSetting.remind_assigns_frequency
      frequency =
        ActiveRecord::Base.sanitize_sql(
          "COALESCE(user_frequency.value, '#{global_frequency}')::INT",
        )

      DB.query_single(<<~SQL)
        SELECT assignments.assigned_to_id
        FROM assignments

        LEFT OUTER JOIN user_custom_fields AS last_reminder
        ON assignments.assigned_to_id = last_reminder.user_id
        AND last_reminder.name = '#{PendingAssignsReminder::REMINDED_AT}'

        LEFT OUTER JOIN user_custom_fields AS user_frequency
        ON assignments.assigned_to_id = user_frequency.user_id
        AND user_frequency.name = '#{PendingAssignsReminder::REMINDERS_FREQUENCY}'

        INNER JOIN group_users ON assignments.assigned_to_id = group_users.user_id
        INNER JOIN topics ON topics.id = assignments.target_id AND assignments.target_type = 'Topic' AND topics.deleted_at IS NULL

        WHERE group_users.group_id IN (#{allowed_group_ids})
        AND #{frequency} > 0
        AND (
          last_reminder.value IS NULL OR
          last_reminder.value::TIMESTAMP <= CURRENT_TIMESTAMP - ('1 MINUTE'::INTERVAL * #{frequency}) + ('1 MINUTE'::INTERVAL * #{REMINDER_BUFFER_MINUTES})
        )
        AND assignments.updated_at::TIMESTAMP <= CURRENT_TIMESTAMP - ('1 MINUTE'::INTERVAL * #{frequency})
        AND assignments.assigned_to_type = 'User'

        GROUP BY assignments.assigned_to_id
        HAVING COUNT(assignments.assigned_to_id) >= #{reminder_threshold}
      SQL
    end
  end
end
