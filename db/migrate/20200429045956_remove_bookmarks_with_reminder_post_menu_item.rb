# frozen_string_literal: true

class RemoveBookmarksWithReminderPostMenuItem < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      UPDATE site_settings SET value = REPLACE(value, '|bookmarkWithReminder|', '|') WHERE name = 'post_menu';
    SQL
    execute <<~SQL
      UPDATE site_settings SET value = REPLACE(value, 'bookmarkWithReminder|', '') WHERE name = 'post_menu';
    SQL
    execute <<~SQL
      UPDATE site_settings SET value = REPLACE(value, '|bookmarkWithReminder', '') WHERE name = 'post_menu';
    SQL
    execute <<~SQL
      UPDATE site_settings SET value = REPLACE(value, '|bookmarkWithReminder|', '|') WHERE name = 'post_menu_hidden';
    SQL
    execute <<~SQL
      UPDATE site_settings SET value = REPLACE(value, 'bookmarkWithReminder|', '') WHERE name = 'post_menu_hidden';
    SQL
    execute <<~SQL
      UPDATE site_settings SET value = REPLACE(value, '|bookmarkWithReminder', '') WHERE name = 'post_menu_hidden';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
