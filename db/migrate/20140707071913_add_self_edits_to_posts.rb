class AddSelfEditsToPosts < ActiveRecord::Migration
  def up
    add_column :posts, :self_edits, :integer, null: false, default: 0
    execute "
    UPDATE posts p SET self_edits = (SELECT COUNT(*) FROM post_revisions pr WHERE pr.post_id = p.id AND pr.user_id=p.user_id)
    "
  end

  def down
    remove_column :posts, :self_edits
  end
end
