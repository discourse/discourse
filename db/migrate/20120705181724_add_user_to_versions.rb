class AddUserToVersions < ActiveRecord::Migration[4.2]
  def change
    execute "UPDATE versions SET user_type = 'User', user_id = posts.user_id
             FROM posts
             WHERE posts.id = versions.versioned_id"
  end
end
