# frozen_string_literal: true

class AddUserIdsToPendingPms < ActiveRecord::Migration[7.2]
  def up
    add_column :discourse_automation_pending_pms, :sender_id, :bigint, null: true
    add_column :discourse_automation_pending_pms, :target_user_ids, :bigint, array: true, null: true

    execute <<~SQL
      UPDATE discourse_automation_pending_pms ppm
      SET sender_id = u.id
      FROM users u
      WHERE u.username = ppm.sender
        AND ppm.sender_id IS NULL
    SQL

    execute <<~SQL
      UPDATE discourse_automation_pending_pms ppm
      SET target_user_ids = subquery.user_ids
      FROM (
        SELECT ppm2.id,
               ARRAY_AGG(u.id ORDER BY array_position(ppm2.target_usernames, u.username)) AS user_ids
        FROM discourse_automation_pending_pms ppm2
        CROSS JOIN LATERAL unnest(ppm2.target_usernames) AS target_username
        JOIN users u ON u.username = target_username
        WHERE ppm2.target_user_ids IS NULL
        GROUP BY ppm2.id
      ) subquery
      WHERE ppm.id = subquery.id
    SQL
  end

  def down
    remove_column :discourse_automation_pending_pms, :sender_id
    remove_column :discourse_automation_pending_pms, :target_user_ids
  end
end
