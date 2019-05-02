# frozen_string_literal: true

class AddHasMessagesToGroups < ActiveRecord::Migration[4.2]
  def up
    add_column :groups, :has_messages, :boolean, default: false, null: false

    execute <<SQL
    UPDATE groups g SET has_messages = true
    WHERE exists(SELECT group_id FROM topic_allowed_groups WHERE group_id = g.id)
SQL

  end

  def down
    remove_column :groups, :has_messages
  end
end
