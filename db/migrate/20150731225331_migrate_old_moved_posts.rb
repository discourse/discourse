# frozen_string_literal: true

class MigrateOldMovedPosts < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE posts SET post_type = 3, action_code = 'split_topic' WHERE post_type = 2 AND raw ~* '^I moved [a\\d]+ posts? to a new topic:'"
    execute "UPDATE posts SET post_type = 3, action_code = 'split_topic' WHERE post_type = 2 AND raw ~* '^I moved [a\\d]+ posts? to an existing topic:'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
