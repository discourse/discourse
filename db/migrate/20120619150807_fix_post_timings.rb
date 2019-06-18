# frozen_string_literal: true

class FixPostTimings < ActiveRecord::Migration[4.2]
  def up
    remove_index :post_timings, [:thread_id, :post_number]
    remove_index :post_timings, [:thread_id, :post_number, :user_id]
    rename_column :post_timings, :thread_id, :forum_thread_id
    add_index :post_timings, [:forum_thread_id, :post_number], name: 'post_timings_summary'
    add_index :post_timings, [:forum_thread_id, :post_number, :user_id], unique: true, name: 'post_timings_unique'

  end

  def down
    rename_column :post_timings, :forum_thread_id, :thread_id
  end
end
