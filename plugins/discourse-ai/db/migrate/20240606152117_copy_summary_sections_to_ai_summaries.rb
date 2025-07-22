# frozen_string_literal: true

class CopySummarySectionsToAiSummaries < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      INSERT INTO ai_summaries (id, target_id, target_type, content_range, summarized_text, original_content_sha, algorithm, created_at, updated_at)
      SELECT id, target_id, target_type, content_range, summarized_text, original_content_sha, algorithm, created_at, updated_at
      FROM summary_sections
      WHERE meta_section_id IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
