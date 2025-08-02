# frozen_string_literal: true

class MarkBookmarksTopicIdNotNull < ActiveRecord::Migration[6.0]
  def change
    change_column_null :bookmarks, :topic_id, false
  end
end
