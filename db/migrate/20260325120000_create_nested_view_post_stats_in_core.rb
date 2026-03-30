# frozen_string_literal: true

class CreateNestedViewPostStatsInCore < ActiveRecord::Migration[8.0]
  def change
    create_table :nested_view_post_stats do |t|
      t.bigint :post_id, null: false
      t.integer :direct_reply_count, default: 0, null: false
      t.integer :total_descendant_count, default: 0, null: false
      t.integer :whisper_direct_reply_count, default: 0, null: false
      t.integer :whisper_total_descendant_count, default: 0, null: false
      t.timestamps
    end

    add_index :nested_view_post_stats, :post_id, unique: true

    create_table :nested_topics do |t|
      t.bigint :topic_id, null: false
      t.bigint :pinned_post_ids, array: true, default: [], null: false
      t.timestamps
    end

    add_index :nested_topics, :topic_id, unique: true

    add_column :category_settings, :nested_replies_default, :boolean, default: false, null: false
  end
end
