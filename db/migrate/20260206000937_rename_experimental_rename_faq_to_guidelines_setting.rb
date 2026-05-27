# frozen_string_literal: true

class RenameExperimentalRenameFaqToGuidelinesSetting < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'rename_faq_to_guidelines'
      WHERE name = 'experimental_rename_faq_to_guidelines'
    SQL

    execute <<~SQL
      UPDATE upcoming_change_events
      SET upcoming_change_name = 'rename_faq_to_guidelines'
      WHERE upcoming_change_name = 'experimental_rename_faq_to_guidelines'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
