# frozen_string_literal: true

class RenameNotifyAboutFlagsAfterSiteSetting < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET name = 'notify_about_reviewable_item_after' WHERE name = 'notify_about_flags_after'"
  end

  def down
    execute "UPDATE site_settings SET name = 'notify_about_flags_after' WHERE name = 'notify_about_reviewable_item_after'"
  end
end
