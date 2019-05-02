# frozen_string_literal: true

class AddPublicVersionToPosts < ActiveRecord::Migration[4.2]
  def up
    add_column :posts, :public_version, :integer, null: false, default: 1

    execute <<-SQL
      UPDATE posts
         SET public_version = 1 + (SELECT COUNT(*) FROM post_revisions pr WHERE post_id = posts.id AND pr.hidden = 'f')
       WHERE public_version <> 1 + (SELECT COUNT(*) FROM post_revisions pr WHERE post_id = posts.id AND pr.hidden = 'f')
    SQL
  end

  def down
    remove_column :posts, :public_version
  end
end
