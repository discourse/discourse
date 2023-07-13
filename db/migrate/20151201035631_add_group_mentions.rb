# frozen_string_literal: true

class AddGroupMentions < ActiveRecord::Migration[4.2]
  def change
    create_table :group_mentions do |t|
      t.integer :post_id
      t.integer :group_id
      t.timestamps null: false
    end

    add_index :group_mentions, %i[post_id group_id], unique: true
    add_index :group_mentions, %i[group_id post_id], unique: true
  end
end
