class MigrateWordCounts < ActiveRecord::Migration
  def up

    disable_ddl_transaction

    post_ids = execute("SELECT id FROM posts WHERE word_count IS NULL LIMIT 500").map {|r| r['id'].to_i }
    while post_ids.length > 0
      execute "UPDATE posts SET word_count = COALESCE(array_length(regexp_split_to_array(raw, ' '),1), 0) WHERE id IN (#{post_ids.join(',')})"
      post_ids = execute("SELECT id FROM posts WHERE word_count IS NULL LIMIT 500").map {|r| r['id'].to_i }
    end

    topic_ids = execute("SELECT id FROM topics WHERE word_count IS NULL LIMIT 500").map {|r| r['id'].to_i }
    while topic_ids.length > 0
      execute "UPDATE topics SET word_count = COALESCE((SELECT SUM(COALESCE(posts.word_count, 0)) FROM posts WHERE posts.topic_id = topics.id), 0) WHERE topics.id IN (#{topic_ids.join(',')})"
      topic_ids = execute("SELECT id FROM topics WHERE word_count IS NULL LIMIT 500").map {|r| r['id'].to_i }
    end

  end

end
