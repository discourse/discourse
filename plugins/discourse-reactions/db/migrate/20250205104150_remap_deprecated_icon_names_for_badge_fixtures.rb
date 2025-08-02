# frozen_string_literal: true
class RemapDeprecatedIconNamesForBadgeFixtures < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      WITH remaps AS (
        SELECT 'smile' AS from_icon, 'face-smile' AS to_icon
      )
      UPDATE badges
      SET icon = remaps.to_icon
      FROM remaps
      WHERE icon = remaps.from_icon;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
