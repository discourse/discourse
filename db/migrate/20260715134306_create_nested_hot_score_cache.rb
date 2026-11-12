# frozen_string_literal: true

class CreateNestedHotScoreCache < ActiveRecord::Migration[8.0]
  def up
    create_table :nested_hot_score_snapshots, id: false do |table|
      table.bigint :topic_id, null: false
      table.datetime :calculated_at, null: false
    end

    add_index :nested_hot_score_snapshots, :topic_id, unique: true
    add_index :nested_hot_score_snapshots, :calculated_at

    create_table :nested_hot_post_scores, id: false do |table|
      table.bigint :post_id, null: false
      table.bigint :topic_id, null: false
      table.float :hot_score, null: false
      table.float :thread_hot_score, null: false
    end

    add_index :nested_hot_post_scores, :post_id, unique: true
    add_index :nested_hot_post_scores, :topic_id
  end

  def down
    drop_table :nested_hot_post_scores
    drop_table :nested_hot_score_snapshots
  end
end
