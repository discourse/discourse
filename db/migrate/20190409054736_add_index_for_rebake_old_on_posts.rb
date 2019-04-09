class AddIndexForRebakeOldOnPosts < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    remove_index :posts, name: :index_posts_on_id_and_baked_version

    add_index :posts, :id,
      order: { id: :desc },
      where: "(baked_version IS NULL OR baked_version < 2) AND deleted_at IS NULL",
      name: :index_for_rebake_old,
      algorithm: :concurrently
  end

  def down
    remove_index :posts, name: :index_for_rebake_old

    add_index :posts, [:id, :baked_version],
      order: { id: :desc },
      where: "(deleted_at IS NULL)",
      algorithm: :concurrently
  end
end
