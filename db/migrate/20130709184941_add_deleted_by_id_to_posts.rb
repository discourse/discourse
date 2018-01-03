class AddDeletedByIdToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :deleted_by_id, :integer, null: true
    add_column :topics, :deleted_by_id, :integer, null: true
    add_column :invites, :deleted_by_id, :integer, null: true
    rename_column :post_actions, :deleted_by, :deleted_by_id
  end
end
