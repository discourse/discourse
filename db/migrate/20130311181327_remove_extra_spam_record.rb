class RemoveExtraSpamRecord < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE post_actions SET post_action_type_id = 7 where post_action_type_id = 8"
    execute "DELETE FROM post_action_types WHERE id = 8"
  end

  def down
  end
end
