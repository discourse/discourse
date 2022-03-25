# frozen_string_literal: true

class CreateTopicInvites < ActiveRecord::Migration[4.2]
  def change
    create_table :topic_invites do |t|
      t.integer :topic_id, null: false
      t.integer :invite_id, null: false
      t.timestamps null: false
    end

    add_index :topic_invites, [:topic_id, :invite_id], unique: true
    add_index :topic_invites, :invite_id
  end
end
