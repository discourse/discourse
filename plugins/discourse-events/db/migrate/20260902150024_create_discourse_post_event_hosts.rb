# frozen_string_literal: true
class CreateDiscoursePostEventHosts < ActiveRecord::Migration[8.0]
  def up
    create_table :discourse_post_event_hosts do |t|
      t.bigint :post_id, null: false
      t.integer :user_id, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :discourse_post_event_hosts, %i[post_id user_id], unique: true
    add_index :discourse_post_event_hosts, :user_id
  end

  def down
    drop_table :discourse_post_event_hosts
  end
end
