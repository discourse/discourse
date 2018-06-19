class CleanUpVotePostAction < ActiveRecord::Migration[5.2]
  def up
    execute "DELETE FROM post_actions WHERE post_action_type_id = 5"
    execute "DELETE FROM post_action_types WHERE id = 5"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
