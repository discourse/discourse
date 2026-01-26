# frozen_string_literal: true

module Migrations::Converters::Discourse
  class UserSuspensions < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM user_histories uh
             JOIN users u ON uh.target_user_id = u.id
        WHERE uh.action = 10 -- Suspend (10)
      SQL
    end

    def items
      @source_db.query <<~SQL
        WITH actions AS (SELECT target_user_id,
                                acting_user_id,
                                action,
                                created_at,
                                details,
                                LEAD(created_at) OVER (PARTITION BY target_user_id ORDER BY id) AS next_action_date,
                                LEAD(action) OVER (PARTITION BY target_user_id ORDER BY id)     AS next_action
                         FROM user_histories
                         WHERE action IN (10, 11) -- Suspend (10) / Unsuspend (11)
        )
        SELECT a.target_user_id AS user_id,
               CASE
                   WHEN ABS(EXTRACT(EPOCH FROM (u.suspended_at - a.created_at))) <= 2
                       THEN u.suspended_at
                   ELSE a.created_at
                   END          AS suspended_at,
               CASE
                   WHEN a.next_action = 11 THEN
                       CASE
                           WHEN ABS(EXTRACT(EPOCH FROM (u.suspended_till - a.next_action_date))) <= 2
                               THEN u.suspended_till
                           ELSE a.next_action_date
                           END
                   ELSE u.suspended_till
                   END          AS suspended_till,
               a.acting_user_id AS suspended_by,
               a.details        AS reason
        FROM actions a
             JOIN users u ON a.target_user_id = u.id
        WHERE a.action = 10 -- Only take suspend actions
        ORDER BY user_id, suspended_at
      SQL
    end

    def process_item(item)
      IntermediateDB::UserSuspension.create(
        user_id: item[:user_id],
        suspended_at: item[:suspended_at],
        suspended_till: item[:suspended_till],
        suspended_by_id: item[:suspended_by_id],
        reason: item[:reason],
      )
    end
  end
end
