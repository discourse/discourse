class AddWelcomeTopicIdSiteSetting < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT 'welcome_topic_id', 3, topic_id, created_at, updated_at
      FROM topic_custom_fields
      WHERE name = 'is_welcome_topic' AND value = 'true'
      LIMIT 1
    SQL

    execute <<~SQL
      DELETE FROM topic_custom_fields
      WHERE name = 'is_welcome_topic' AND value = 'true'
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
      WHERE name = 'welcome_topic_id'
    SQL
  end
end
