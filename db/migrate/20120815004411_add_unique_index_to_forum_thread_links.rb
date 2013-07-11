class AddUniqueIndexToForumThreadLinks < ActiveRecord::Migration
  def change

    execute "DELETE FROM forum_thread_links USING forum_thread_links ftl2
              WHERE ftl2.forum_thread_id = forum_thread_links.forum_thread_id
                              AND ftl2.post_id = forum_thread_links.post_id
                              AND ftl2.url = forum_thread_links.url
                              AND ftl2.id < forum_thread_links.id"

    # Add the unique index
    add_index :forum_thread_links, [:forum_thread_id, :post_id, :url], unique: true, name: 'unique_post_links'
  end
end
