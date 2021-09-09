# frozen_string_literal: true

class MakeTopicIdNullableForBookmarks < ActiveRecord::Migration[6.1]
  def up
    change_column_null :bookmarks, :topic_id, true
  end
  def down
    change_column_null :bookmarks, :topic_id, false
  end
end
