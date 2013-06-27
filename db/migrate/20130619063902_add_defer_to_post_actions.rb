class AddDeferToPostActions < ActiveRecord::Migration
  def change
    # an action can be deferred by a moderator, used for flags
    add_column :post_actions, :defer, :boolean
    add_column :post_actions, :defer_by, :int
  end
end
