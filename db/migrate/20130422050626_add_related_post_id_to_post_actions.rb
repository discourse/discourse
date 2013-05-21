class AddRelatedPostIdToPostActions < ActiveRecord::Migration
  def change
    add_column :post_actions, :related_post_id, :integer
  end
end
