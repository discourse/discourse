# frozen_string_literal: true
class DropHorizonSettingField < ActiveRecord::Migration[8.0]
  def up
    old_setting_field_id = DB.query_single(<<~SQL).first
      SELECT id FROM theme_fields
      WHERE theme_id = -2 AND name = 'yaml' AND target_id = 3
    SQL

    return if old_setting_field_id.nil?

    # target_id 3 is Theme.targets[:settings]
    # ID -2 is always the Horizon theme since it's a core theme
    DB.exec(<<~SQL)
      DELETE FROM theme_fields
      WHERE id = #{old_setting_field_id}
    SQL

    DB.exec(<<~SQL)
      DELETE FROM javascript_caches
      WHERE theme_field_id = #{old_setting_field_id}
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
