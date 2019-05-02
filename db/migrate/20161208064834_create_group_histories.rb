# frozen_string_literal: true

class CreateGroupHistories < ActiveRecord::Migration[4.2]
  def change
    create_table :group_histories do |t|
      t.integer :group_id, null: false
      t.integer :acting_user_id, null: false
      t.integer :target_user_id
      t.integer :action, index: true, null: false
      t.string :subject
      t.text :prev_value
      t.text :new_value

      t.timestamps null: false
    end

    add_index :group_histories, :group_id
    add_index :group_histories, :acting_user_id
    add_index :group_histories, :target_user_id
  end
end
