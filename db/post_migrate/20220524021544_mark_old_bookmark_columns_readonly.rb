# frozen_string_literal: true

class MarkOldBookmarkColumnsReadonly < ActiveRecord::Migration[7.0]
  def up
    Migration::ColumnDropper.mark_readonly(:bookmarks, :for_topic)
    Migration::ColumnDropper.mark_readonly(:bookmarks, :post_id)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:bookmarks, :for_topic)
    Migration::ColumnDropper.drop_readonly(:bookmarks, :post_id)
  end
end
