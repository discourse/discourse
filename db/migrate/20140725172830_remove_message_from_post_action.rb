class RemoveMessageFromPostAction < ActiveRecord::Migration[4.2]
  def up
    remove_column :post_actions, :message
  end

  def down
    add_column :post_actions, :message, :text

    execute "UPDATE post_actions
                SET message = p.raw
               FROM post_actions pa
          LEFT JOIN posts p ON p.id = pa.related_post_id
              WHERE post_actions.id = pa.id
                AND pa.related_post_id IS NOT NULL;"
  end
end
