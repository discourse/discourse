# frozen_string_literal: true

class CategoryTagStat < ActiveRecord::Base
  belongs_to :category
  belongs_to :tag

  def self.topic_moved(topic, from_category_id, to_category_id)
    if from_category_id
      self
        .where(tag_id: topic.tags.map(&:id), category_id: from_category_id)
        .where("topic_count > 0")
        .update_all("topic_count = topic_count - 1")
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
    # Add new records or update existing records
    DB.exec <<~SQL
      WITH stats AS (
        SELECT topics.category_id as category_id,
               tags.id AS tag_id,
               COUNT(topics.id) AS topic_count
        FROM tags
        INNER JOIN topic_tags ON tags.id = topic_tags.tag_id
        INNER JOIN topics ON topics.id = topic_tags.topic_id
               AND topics.deleted_at IS NULL
               AND topics.category_id IS NOT NULL
        GROUP BY topics.category_id, tags.id
      )
      INSERT INTO category_tag_stats(category_id, tag_id, topic_count)
      SELECT category_id, tag_id, topic_count FROM stats
      ON CONFLICT (category_id, tag_id) DO
      UPDATE SET topic_count = EXCLUDED.topic_count
    SQL

    # Delete old records
    DB.exec <<~SQL
      DELETE FROM category_tag_stats
      WHERE (category_id, tag_id) NOT IN (
        SELECT topics.category_id as category_id,
               tags.id AS tag_id
        FROM tags
        INNER JOIN topic_tags ON tags.id = topic_tags.tag_id
        INNER JOIN topics ON topics.id = topic_tags.topic_id
               AND topics.deleted_at IS NULL
               AND topics.category_id IS NOT NULL
        GROUP BY topics.category_id, tags.id
      )
    SQL
  end
end

# == Schema Information
#
# Table name: category_tag_stats
#
#  id          :bigint           not null, primary key
#  category_id :bigint           not null
#  tag_id      :bigint           not null
#  topic_count :integer          default(0), not null
#
# Indexes
#
#  index_category_tag_stats_on_category_id                  (category_id)
#  index_category_tag_stats_on_category_id_and_tag_id       (category_id,tag_id) UNIQUE
#  index_category_tag_stats_on_category_id_and_topic_count  (category_id,topic_count)
#  index_category_tag_stats_on_tag_id                       (tag_id)
#
