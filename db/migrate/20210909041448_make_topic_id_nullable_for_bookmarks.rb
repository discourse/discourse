# frozen_string_literal: true

class MakeTopicIdNullableForBookmarks < ActiveRecord::Migration[6.1]
  def up
    change_column_null :bookmarks, :topic_id, true
    Migration::ColumnDropper.mark_readonly(:bookmarks, :topic_id)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:bookmarks, :topic_id)
    change_column_null :bookmarks, :topic_id, false
  end
end
