# frozen_string_literal: true

class RenameSettingToDiscoursePostEvent < ActiveRecord::Migration[6.0]
  def up
    execute "UPDATE site_settings SET name = 'discourse_post_event_enabled' WHERE name = 'post_event_enabled'"
  end

  def down
    execute "UPDATE site_settings SET name = 'post_event_enabled' WHERE name = 'discourse_post_event_enabled'"
  end
end
