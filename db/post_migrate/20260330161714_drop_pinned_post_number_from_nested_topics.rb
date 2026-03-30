# frozen_string_literal: true

class DropPinnedPostNumberFromNestedTopics < ActiveRecord::Migration[8.0]
  def up
    remove_column :nested_topics, :pinned_post_number
  end

  def down
    add_column :nested_topics, :pinned_post_number, :integer
  end
end
