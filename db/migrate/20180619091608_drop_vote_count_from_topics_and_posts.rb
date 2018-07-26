class DropVoteCountFromTopicsAndPosts < ActiveRecord::Migration[5.2]
  def up
    # Delayed drop
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
