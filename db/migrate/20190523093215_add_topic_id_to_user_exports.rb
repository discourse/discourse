# frozen_string_literal: true

class AddTopicIdToUserExports < ActiveRecord::Migration[5.2]
  def up
    add_column :user_exports, :topic_id, :integer
  end

  def down
    remove_column :user_exports, :topic_id
  end
end
