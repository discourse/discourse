class AddUserToVersions < ActiveRecord::Migration
  def change
    execute "UPDATE versions SET user_type = 'User', user_id = posts.user_id
             FROM posts
             WHERE posts.id = versions.versioned_id"
  end
end
