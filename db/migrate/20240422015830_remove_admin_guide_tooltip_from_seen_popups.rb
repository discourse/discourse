# frozen_string_literal: true

class RemoveAdminGuideTooltipFromSeenPopups < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE user_options SET seen_popups = ARRAY_REMOVE(user_options2.seen_popups, 6)
      FROM (SELECT user_id, seen_popups FROM user_options) AS user_options2
      WHERE 6 = ANY (user_options.seen_popups)
        AND user_options.user_id = user_options2.user_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
