# frozen_string_literal: true

class RemoveBookmarksDeleteWhenReminderSent < ActiveRecord::Migration[6.0]
  def up
    remove_column :bookmarks, :delete_when_reminder_sent
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
