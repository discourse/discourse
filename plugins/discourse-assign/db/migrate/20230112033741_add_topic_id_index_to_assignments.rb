# frozen_string_literal: true

class AddTopicIdIndexToAssignments < ActiveRecord::Migration[7.0]
  def change
    add_index :assignments, :topic_id
  end
end
