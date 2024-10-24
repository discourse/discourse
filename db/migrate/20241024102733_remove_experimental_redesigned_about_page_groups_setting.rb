# frozen_string_literal: true

class RemoveExperimentalRedesignedAboutPageGroupsSetting < ActiveRecord::Migration[7.1]
  def up
    execute(<<~SQL)
      DELETE FROM site_settings
      WHERE name = 'experimental_redesigned_about_page_groups'
    SQL
  end

  def down
    raise IrreversibleMigration.new
  end
end
