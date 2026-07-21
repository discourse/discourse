# frozen_string_literal: true

class MigrateDuplicateTopicTitlesSettings < ActiveRecord::Migration[8.0]
  def up
    allow_all =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'allow_duplicate_topic_titles'",
      ).first
    allow_across =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'allow_duplicate_topic_titles_category'",
      ).first

    new_value =
      if allow_all == "t"
        "allowed"
      elsif allow_across == "t"
        "allowed_across_categories"
      end

    DB.exec(<<~SQL, value: new_value) if new_value
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('duplicate_topic_titles', 7, :value, NOW(), NOW())
        ON CONFLICT DO NOTHING
      SQL
  end

  def down
    execute "DELETE FROM site_settings WHERE name = 'duplicate_topic_titles'"
  end
end
