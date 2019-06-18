# frozen_string_literal: true

class AddIndexForRebakeOldOnPosts < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    if index_exists?(:posts, :index_posts_on_id_and_baked_version)
      remove_index :posts, name: :index_posts_on_id_and_baked_version
    end

    if !index_exists?(:posts, :index_for_rebake_old)
      add_index :posts, :id,
        order: { id: :desc },
        where: "(baked_version IS NULL OR baked_version < 2) AND deleted_at IS NULL",
        name: :index_for_rebake_old,
        algorithm: :concurrently
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
