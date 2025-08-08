# frozen_string_literal: true

module Migrations::Importer::Steps
  class AnniversaryUserBadges < ::Migrations::Importer::Step
    depends_on :user_badges

    def execute
      super

      return unless SiteSetting.enable_badges?

      # TODO:(selase): Explore scoping the update to only imported users
      DB.exec(<<~SQL)
        WITH
          eligible_users AS (
                              SELECT u.id, u.created_at
                              FROM users u
                              WHERE u.active
                                AND NOT u.staged
                                AND u.id > 0
                                AND (u.silenced_till IS NULL OR u.silenced_till < CURRENT_TIMESTAMP)
                                AND (u.suspended_till IS NULL OR u.suspended_till < CURRENT_TIMESTAMP)
                                AND NOT EXISTS (SELECT 1 FROM anonymous_users AS au WHERE au.user_id = u.id)
                            ),
          anniversary_dates AS ( -- Series of anniversary dates starting from the user's created_at + 1 year up to the current year
                                 SELECT
                                   eu.id AS user_id,
                                   (
                                     eu.created_at +
                                     ((year_num - EXTRACT(YEAR FROM eu.created_at)) || ' years')::interval
                                   )::timestamp AS anniversary_date
                                 FROM eligible_users eu,
                                      generate_series(
                                        EXTRACT(YEAR FROM eu.created_at)::int + 1,
                                        EXTRACT(YEAR FROM CURRENT_TIMESTAMP)::int
                                      ) AS year_num
                                  WHERE
                                    (
                                      eu.created_at +
                                      ((year_num - EXTRACT(YEAR FROM eu.created_at)) || ' years')::interval
                                    ) < CURRENT_TIMESTAMP
                               )
        INSERT INTO user_badges (granted_at, created_at, granted_by_id, user_id, badge_id, seq)
        SELECT a.anniversary_date,
              CURRENT_TIMESTAMP,
              #{Discourse::SYSTEM_USER_ID},
              a.user_id,
               #{Badge::Anniversary},
              (ROW_NUMBER() OVER (PARTITION BY a.user_id ORDER BY a.anniversary_date) - 1) AS seq
        FROM anniversary_dates a
            JOIN eligible_users u ON a.user_id = u.id
            JOIN posts  AS p ON p.user_id = u.id
            JOIN topics AS t ON p.topic_id = t.id
        WHERE p.deleted_at IS NULL
          AND NOT p.hidden
          AND p.created_at BETWEEN a.anniversary_date - '1 year'::interval AND a.anniversary_date
          AND t.visible
          AND t.archetype <> 'private_message'
          AND t.deleted_at IS NULL
          AND NOT EXISTS (
              SELECT 1
              FROM user_badges AS ub
              WHERE ub.user_id = u.id
              AND ub.badge_id =  #{Badge::Anniversary}
              AND ub.granted_at BETWEEN a.anniversary_date - '1 year'::interval AND a.anniversary_date
          )
        GROUP BY a.user_id, a.anniversary_date
      SQL

      UserBadge.update_featured_ranks!
    end
  end
end
