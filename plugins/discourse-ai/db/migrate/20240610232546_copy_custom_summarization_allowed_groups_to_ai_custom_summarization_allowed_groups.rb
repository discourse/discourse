# frozen_string_literal: true

class CopyCustomSummarizationAllowedGroupsToAiCustomSummarizationAllowedGroups < ActiveRecord::Migration[
  7.0
]
  def up
    execute <<-SQL
      UPDATE site_settings
      SET data_type = (SELECT data_type FROM site_settings WHERE name = 'custom_summarization_allowed_groups'),
          value = (SELECT value FROM site_settings WHERE name = 'custom_summarization_allowed_groups')
      WHERE name = 'ai_custom_summarization_allowed_groups'
      AND EXISTS (SELECT 1 FROM site_settings WHERE name = 'custom_summarization_allowed_groups');
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
