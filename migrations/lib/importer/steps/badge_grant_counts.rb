# frozen_string_literal: true

module Migrations::Importer::Steps
  class BadgeGrantCounts < ::Migrations::Importer::Step
    depends_on :user_badges, :anniversary_user_badges

    def execute
      super

      DB.exec(<<~SQL)
        WITH
            grants AS (
                        SELECT badge_id, COUNT(*) AS grant_count FROM user_badges GROUP BY badge_id
                      )
        UPDATE badges
          SET grant_count = grants.grant_count
          FROM grants
         WHERE badges.id = grants.badge_id
           AND badges.grant_count <> grants.grant_count
      SQL
    end
  end
end
