# frozen_string_literal: true

# The `reporting_improvements` upcoming change moved from
# `allow_enabled_for: [everyone]` to `[staff, specific_groups]`. Existing sites
# where an admin had explicitly enabled it (DB value = 't') previously had it on
# for "Everyone" since no SiteSettingGroup row existed. "Everyone" is no longer
# a permitted target, so seed a SiteSettingGroup row pointing at the staff auto
# group (id 3) for those sites, preserving the opt-in at the narrowest now-valid
# scope.
class ConvertReportingImprovementsEveryoneToStaff < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL)
      INSERT INTO site_setting_groups (name, group_ids, created_at, updated_at)
      SELECT 'reporting_improvements', '3', NOW(), NOW()
      WHERE EXISTS (
        SELECT 1 FROM site_settings
        WHERE name = 'reporting_improvements' AND value = 't'
      )
      AND NOT EXISTS (
        SELECT 1 FROM site_setting_groups WHERE name = 'reporting_improvements'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
