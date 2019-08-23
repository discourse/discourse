# frozen_string_literal: true

class TopicGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :topic

  def self.update_last_read(user, topic_id, post_number)
    updated_groups = update_read_count(user, topic_id, post_number)
    create_topic_group(user, topic_id, post_number, updated_groups.map(&:group_id))
    TopicTrackingState.publish_read_indicator_on_read(topic_id, post_number, user.id)
  end

  def self.new_message_update(user, topic_id, post_number)
    updated_groups = update_read_count(user, topic_id, post_number)
    create_topic_group(user, topic_id, post_number, updated_groups.map(&:group_id))
    TopicTrackingState.publish_read_indicator_on_write(topic_id, post_number, user.id)
  end

  def self.update_read_count(user, topic_id, post_number)
    update_query = <<~SQL
      UPDATE topic_groups tg
      SET
        last_read_post_number = GREATEST(:post_number, tg.last_read_post_number),
        updated_at = :now
      FROM topic_allowed_groups tag
      INNER JOIN group_users gu ON gu.group_id = tag.group_id
      WHERE gu.user_id = :user_id
      AND tag.topic_id = :topic_id
      AND tg.topic_id = :topic_id
      RETURNING
        tg.group_id
    SQL

    updated_groups = DB.query(
      update_query,
      user_id: user.id, topic_id: topic_id, post_number: post_number, now: DateTime.now
    )
  end

  def self.create_topic_group(user, topic_id, post_number, updated_group_ids)
    query = <<~SQL
      INSERT INTO topic_groups (topic_id, group_id, last_read_post_number, created_at, updated_at)
      SELECT tag.topic_id, tag.group_id, :post_number, :now, :now
      FROM topic_allowed_groups tag
      INNER JOIN group_users gu ON gu.group_id = tag.group_id
      WHERE gu.user_id = :user_id
      AND tag.topic_id = :topic_id
    SQL

    query += 'AND NOT(tag.group_id IN (:already_updated_groups))' unless updated_group_ids.length.zero?

    DB.exec(
      query,
      user_id: user.id, topic_id: topic_id, post_number: post_number, now: DateTime.now, already_updated_groups: updated_group_ids
    )
  end
end

# == Schema Information
#
# Table name: topic_groups
#
#  id                     :integer          not null, primary key
#  group_id               :integer          not null
#  topic_id               :integer          not null
#  last_read_post_number  :integer          default(0), not null
#
# Indexes
#
#  index_topic_allowed_groups_on_group_id_and_topic_id  (group_id,topic_id) UNIQUE
#
