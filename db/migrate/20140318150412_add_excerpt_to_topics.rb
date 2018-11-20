class AddExcerptToTopics < ActiveRecord::Migration[4.2]
  def up
    add_column :topics, :excerpt, :string, limit: 1000

    topic_ids = execute("SELECT id FROM topics WHERE pinned_at IS NOT NULL").map { |r| r['id'].to_i }
    topic_ids.each do |topic_id|
      cooked = execute("SELECT cooked FROM posts WHERE topic_id = #{topic_id} ORDER BY post_number ASC LIMIT 1")[0]['cooked']
      if cooked
        excerpt = ExcerptParser.get_excerpt(cooked, 220, strip_links: true)
        execute "UPDATE topics SET excerpt = #{ActiveRecord::Base.sanitize(excerpt)} WHERE id = #{topic_id}"
      end
    end
  end

  def down
    remove_column :topics, :excerpt
  end
end
