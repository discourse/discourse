# frozen_string_literal: true

class CreateActions < ActiveRecord::Migration[4.2]
  def change
    create_table :actions do |t|

      # I elected for multiple ids as opposed to using :as cause it makes the table
      # thinner, and the joining semantics much simpler (a simple multiple left join will do)
      #
      # There is a notificiation table as well that covers much of this,
      # but this table is wider and is intended for non-notifying actions as well

      t.integer :action_type, null: false
      t.integer :user_id, null: false
      t.integer :target_forum_thread_id
      t.integer :target_post_id
      t.integer :target_user_id
      t.integer :acting_user_id

      t.timestamps null: false
    end

    add_index :actions, [:user_id, :action_type]
    add_index :actions, [:acting_user_id]
  end
end
