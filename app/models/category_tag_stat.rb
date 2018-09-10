class CategoryTagStat < ActiveRecord::Base
  belongs_to :category
  belongs_to :tag

  def self.topic_moved(topic, from_category_id, to_category_id)
    if from_category_id
      self.where(tag_id: topic.tags.map(&:id), category_id: from_category_id)
        .where('topic_count > 0')
        .update_all('topic_count = topic_count - 1')
    end

    if to_category_id
      sql = <<~SQL
        UPDATE #{self.table_name}
           SET topic_count = topic_count + 1
         WHERE tag_id in (:tag_ids)
           AND category_id = :category_id
     RETURNING tag_id
      SQL

      tag_ids = topic.tags.map(&:id)
      updated_tag_ids = DB.query_single(sql, tag_ids: tag_ids, category_id: to_category_id)

      (tag_ids - updated_tag_ids).each do |tag_id|
        CategoryTagStat.create!(tag_id: tag_id, category_id: to_category_id, topic_count: 1)
      end
    end
  end

  def self.topic_deleted(topic)
    topic_moved(topic, topic.category_id, nil)
  end

  def self.topic_recovered(topic)
    topic_moved(topic, nil, topic.category_id)
  end

  def self.ensure_consistency!
    self.update_topic_counts
  end

  # Recalculate all topic counts if they got out of sync
  def self.update_topic_counts
    DB.exec <<~SQL
      UPDATE category_tag_stats stats
      SET topic_count = x.topic_count
      FROM (
        SELECT COUNT(topics.id) AS topic_count,
               tags.id AS tag_id,
               topics.category_id as category_id
        FROM tags
        INNER JOIN topic_tags ON tags.id = topic_tags.tag_id
        INNER JOIN topics ON topics.id = topic_tags.topic_id
               AND topics.deleted_at IS NULL
               AND topics.category_id IS NOT NULL
        GROUP BY tags.id, topics.category_id
      ) x
      WHERE stats.tag_id = x.tag_id
        AND stats.category_id = x.category_id
        AND x.topic_count <> stats.topic_count
    SQL
  end
end

# == Schema Information
#
# Table name: category_tag_stats
#
#  id          :bigint(8)        not null, primary key
#  category_id :bigint(8)        not null
#  tag_id      :bigint(8)        not null
#  topic_count :integer          default(0), not null
#
# Indexes
#
#  index_category_tag_stats_on_category_id                  (category_id)
#  index_category_tag_stats_on_category_id_and_tag_id       (category_id,tag_id) UNIQUE
#  index_category_tag_stats_on_category_id_and_topic_count  (category_id,topic_count)
#  index_category_tag_stats_on_tag_id                       (tag_id)
#
