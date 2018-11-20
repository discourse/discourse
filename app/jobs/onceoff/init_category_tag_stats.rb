module Jobs
  class InitCategoryTagStats < Jobs::Onceoff
    def execute_onceoff(args)
      DB.exec "DELETE FROM category_tag_stats"

      DB.exec <<~SQL
    INSERT INTO category_tag_stats (category_id, tag_id, topic_count)
         SELECT topics.category_id, tags.id, COUNT(topics.id)
           FROM tags
     INNER JOIN topic_tags ON tags.id = topic_tags.tag_id
     INNER JOIN topics ON topics.id = topic_tags.topic_id
            AND topics.deleted_at IS NULL
            AND topics.category_id IS NOT NULL
       GROUP BY tags.id, topics.category_id
      SQL
    end
  end
end
