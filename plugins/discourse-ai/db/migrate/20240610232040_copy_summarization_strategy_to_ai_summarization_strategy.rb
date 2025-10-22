# frozen_string_literal: true

class CopySummarizationStrategyToAiSummarizationStrategy < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      UPDATE site_settings
      SET data_type = (SELECT data_type FROM site_settings WHERE name = 'summarization_strategy'),
          value = (SELECT value FROM site_settings WHERE name = 'summarization_strategy')
      WHERE name = 'ai_summarization_strategy'
      AND EXISTS (SELECT 1 FROM site_settings WHERE name = 'summarization_strategy');
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
