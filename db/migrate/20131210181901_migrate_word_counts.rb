class MigrateWordCounts < ActiveRecord::Migration
  disable_ddl_transaction!

  def up
    post_ids = execute("SELECT id FROM posts WHERE word_count IS NULL LIMIT 500").map {|r| r['id'].to_i }
    while post_ids.length > 0
      3.times do
        begin
          execute "UPDATE posts SET word_count = COALESCE(array_length(regexp_split_to_array(raw, ' '),1), 0) WHERE id IN (#{post_ids.join(',')})"
          break
        rescue PG::Error
          # Deadlock. Try again, up to 3 times.
        end
      end
      post_ids = execute("SELECT id FROM posts WHERE word_count IS NULL LIMIT 500").map {|r| r['id'].to_i }
    end

    topic_ids = execute("SELECT id FROM topics WHERE word_count IS NULL LIMIT 500").map {|r| r['id'].to_i }
    while topic_ids.length > 0
      3.times do
        begin
          execute "UPDATE topics SET word_count = COALESCE((SELECT SUM(COALESCE(posts.word_count, 0)) FROM posts WHERE posts.topic_id = topics.id), 0) WHERE topics.id IN (#{topic_ids.join(',')})"
          break
        rescue PG::Error
          # Deadlock. Try again, up to 3 times.
        end
      end
      topic_ids = execute("SELECT id FROM topics WHERE word_count IS NULL LIMIT 500").map {|r| r['id'].to_i }
    end

  end

end
