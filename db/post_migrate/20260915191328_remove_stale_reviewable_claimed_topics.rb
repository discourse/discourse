# frozen_string_literal: true

class RemoveStaleReviewableClaimedTopics < ActiveRecord::Migration[8.0]
  def up
    # A manual claim is only live while a reviewable on its topic has been pending since before
    # the claim was made. Anything else was left behind by a reviewable that has since been
    # resolved (and possibly reopened), so later reviewables on the topic inherited it.
    # reviewable_history_type 0 = created, 1 = transitioned; status 0 = pending.
    execute <<~SQL
      DELETE FROM reviewable_claimed_topics rct
      WHERE NOT rct.automatic
        AND NOT EXISTS (
          SELECT 1
          FROM reviewables r
          WHERE r.topic_id = rct.topic_id
            AND r.status = 0
            AND COALESCE(
              (
                SELECT MAX(rh.created_at)
                FROM reviewable_histories rh
                WHERE rh.reviewable_id = r.id
                  AND rh.reviewable_history_type IN (0, 1)
              ),
              r.created_at
            ) <= rct.created_at
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
