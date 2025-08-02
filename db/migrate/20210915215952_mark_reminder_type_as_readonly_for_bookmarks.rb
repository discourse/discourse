# frozen_string_literal: true

class MarkReminderTypeAsReadonlyForBookmarks < ActiveRecord::Migration[6.1]
  def up
    Migration::ColumnDropper.mark_readonly(:bookmarks, :reminder_type)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:bookmarks, :reminder_type)
  end
end
