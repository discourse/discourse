# frozen_string_literal: true

class RemoveTagsFromAdobeAnalyticsUrl < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'adobe_analytics_url'
      WHERE name = 'adobe_analytics_tags_url'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings
      SET name = 'adobe_analytics_tags_url'
      WHERE name = 'adobe_analytics_url'
    SQL
  end
end
