# frozen_string_literal: true

class RenameExperimentalFormTemplatesSetting < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'enable_form_templates'
      WHERE name = 'experimental_form_templates'
    SQL

    execute <<~SQL
      UPDATE upcoming_change_events
      SET upcoming_change_name = 'enable_form_templates'
      WHERE upcoming_change_name = 'experimental_form_templates'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
