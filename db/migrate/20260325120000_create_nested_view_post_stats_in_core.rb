# frozen_string_literal: true

class CreateNestedViewPostStatsInCore < ActiveRecord::Migration[8.0]
  def change
    create_table :nested_view_post_stats, if_not_exists: true do |t|
      t.bigint :post_id, null: false
      t.integer :direct_reply_count, default: 0, null: false
      t.integer :total_descendant_count, default: 0, null: false
      t.integer :whisper_direct_reply_count, default: 0, null: false
      t.integer :whisper_total_descendant_count, default: 0, null: false
      t.timestamps
    end

    add_index :nested_view_post_stats, :post_id, unique: true, if_not_exists: true

    create_table :nested_topics, if_not_exists: true do |t|
      t.bigint :topic_id, null: false
      t.bigint :pinned_post_ids, array: true, default: [], null: false
      t.timestamps
    end

    # On sites that ran the nested-replies plugin, nested_topics was created with
    # pinned_post_number instead of pinned_post_ids. Add the new column if missing.
    unless column_exists?(:nested_topics, :pinned_post_ids)
      add_column :nested_topics, :pinned_post_ids, :bigint, array: true, default: [], null: false
    end

    add_index :nested_topics, :topic_id, unique: true, if_not_exists: true

    unless column_exists?(:category_settings, :nested_replies_default)
      add_column :category_settings, :nested_replies_default, :boolean, default: false, null: false
    end
  end
end
