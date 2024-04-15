# frozen_string_literal: true

class CreateSummarySectionsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :summary_sections do |t|
      t.integer :target_id, null: false
      t.string :target_type, null: false
      t.int4range :content_range
      t.string :summarized_text, null: false
      t.integer :meta_section_id
      t.string :original_content_sha, null: false
      t.string :algorithm, null: false
      t.timestamps
    end
  end
end
