# frozen_string_literal: true

class RemoveTopicIdIndex < ActiveRecord::Migration[6.1]
  def change
    remove_index :assignments, :topic_id
  end
end
