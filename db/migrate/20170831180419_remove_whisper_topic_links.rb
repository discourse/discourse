class RemoveWhisperTopicLinks < ActiveRecord::Migration
  def change
    execute <<-SQL
      DELETE FROM topic_links
       USING topic_links tl
   LEFT JOIN posts p ON p.id = tl.post_id
       WHERE p.post_type = 4
         AND topic_links.id = tl.id
    SQL
  end
end
