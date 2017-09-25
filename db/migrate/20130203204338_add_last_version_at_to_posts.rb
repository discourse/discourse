class AddLastVersionAtToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :last_version_at, :timestamp
    execute "UPDATE posts SET last_version_at = COALESCE((SELECT max(created_at)
                                                 FROM versions WHERE versions.versioned_id = posts.id
                                                    AND versions.versioned_type = 'Post'), posts.created_at)"
    change_column :posts, :last_version_at, :timestamp, null: false
  end
end
