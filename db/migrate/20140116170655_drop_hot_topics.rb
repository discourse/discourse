# frozen_string_literal: true

class DropHotTopics < ActiveRecord::Migration[4.2]
  def change
    drop_table :hot_topics
  end
end
