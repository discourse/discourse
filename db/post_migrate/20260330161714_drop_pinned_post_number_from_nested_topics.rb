# frozen_string_literal: true

class DropPinnedPostNumberFromNestedTopics < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:nested_topics, :pinned_post_number)
      remove_column :nested_topics, :pinned_post_number
    end
  end

  def down
    unless column_exists?(:nested_topics, :pinned_post_number)
      add_column :nested_topics, :pinned_post_number, :integer
    end
  end
end
