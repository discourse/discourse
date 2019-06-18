# frozen_string_literal: true

class AddMissingTopicIdSiteSettings < ActiveRecord::Migration[5.2]
  def up
    # Welcome Topic
    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT 'welcome_topic_id', 3, topic_id, created_at, updated_at
      FROM topic_custom_fields
      WHERE name = 'is_welcome_topic' AND value = 'true' AND NOT EXISTS(
          SELECT 1
          FROM site_settings
          WHERE name = 'welcome_topic_id'
        )
      LIMIT 1
    SQL

    execute <<~SQL
      DELETE FROM topic_custom_fields
      WHERE name = 'is_welcome_topic' AND value = 'true'
    SQL

    # Lounge Welcome Topic
    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT 'lounge_welcome_topic_id', 3, id, created_at, updated_at
      FROM topics
      WHERE title = 'Welcome to the Lounge' AND NOT EXISTS(
          SELECT 1
          FROM site_settings
          WHERE name = 'lounge_welcome_topic_id'
        ) AND category_id IN (
        SELECT value::INT
        FROM site_settings
        WHERE name = 'lounge_category_id'
      )
      ORDER BY created_at
      LIMIT 1
    SQL

    # Admin Quick Start Guide
    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT 'admin_quick_start_topic_id', 3, id, created_at, updated_at
      FROM topics
      WHERE title IN ('READ ME FIRST: Admin Quick Start Guide', 'READ ME FIRST: Getting Started') AND NOT EXISTS(
          SELECT 1
          FROM site_settings
          WHERE name = 'admin_quick_start_topic_id'
        )
      ORDER BY created_at
      LIMIT 1
    SQL
  end

  def down
    execute <<~SQL
      INSERT INTO topic_custom_fields(topic_id, name, value, created_at, updated_at)
      SELECT value::INTEGER, 'is_welcome_topic', 'true', created_at, updated_at
      FROM site_settings
      WHERE name = 'welcome_topic_id'
    SQL

    execute <<~SQL
      DELETE FROM site_settings
      WHERE name IN ('welcome_topic_id', 'lounge_welcome_topic_id', 'admin_quick_start_topic_id')
    SQL
  end
end
