# frozen_string_literal: true

class CreateNestedViewPostStatsInCore < ActiveRecord::Migration[8.0]
  def up
    return if table_exists?(:nested_view_post_stats)

    create_table :nested_view_post_stats do |t|
      t.bigint :post_id, null: false
      t.integer :direct_reply_count, default: 0, null: false
      t.integer :total_descendant_count, default: 0, null: false
      t.integer :whisper_direct_reply_count, default: 0, null: false
      t.integer :whisper_total_descendant_count, default: 0, null: false
      t.timestamps
    end

    add_index :nested_view_post_stats, :post_id, unique: true
  end

  def down
    drop_table :nested_view_post_stats if table_exists?(:nested_view_post_stats)
  end
end
