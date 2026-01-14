# frozen_string_literal: true

class CreateAiSummariesTable < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_summaries do |t|
      t.integer :target_id, null: false
      t.string :target_type, null: false
      t.int4range :content_range
      t.string :summarized_text, null: false
      t.string :original_content_sha, null: false
      t.string :algorithm, null: false
      t.timestamps
    end
  end
end
