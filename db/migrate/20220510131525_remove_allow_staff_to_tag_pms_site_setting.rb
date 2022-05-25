# frozen_string_literal: true
class RemoveAllowStaffToTagPmsSiteSetting < ActiveRecord::Migration[7.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'allow_staff_to_tag_pms'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
