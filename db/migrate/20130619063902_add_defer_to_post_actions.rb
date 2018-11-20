class AddDeferToPostActions < ActiveRecord::Migration[4.2]
  def change
    # an action can be deferred by a moderator, used for flags
    add_column :post_actions, :defer, :boolean
    add_column :post_actions, :defer_by, :int
  end
end
