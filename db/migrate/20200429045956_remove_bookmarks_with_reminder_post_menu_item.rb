# frozen_string_literal: true

class RemoveBookmarksWithReminderPostMenuItem < ActiveRecord::Migration[6.0]
  def up
    post_menu = SiteSetting.post_menu
    post_menu = post_menu.gsub("|bookmarkWithReminder|", "|")
    post_menu = post_menu.gsub("bookmarkWithReminder|", "")
    post_menu = post_menu.gsub("|bookmarkWithReminder", "")

    SiteSetting.post_menu = post_menu

    post_menu_hidden = SiteSetting.post_menu_hidden_items
    post_menu_hidden = post_menu_hidden.gsub("|bookmarkWithReminder|", "|")
    post_menu_hidden = post_menu_hidden.gsub("bookmarkWithReminder|", "")
    post_menu_hidden = post_menu_hidden.gsub("|bookmarkWithReminder", "")

    SiteSetting.post_menu_hidden_items = post_menu_hidden
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
