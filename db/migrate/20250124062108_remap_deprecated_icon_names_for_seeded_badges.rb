# frozen_string_literal: true
#
class RemapDeprecatedIconNamesForSeededBadges < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      WITH remaps AS (
        SELECT from_icon, to_icon
        FROM (VALUES ('smile', 'face-smile'), ('share-alt', 'share-nodes'))
        AS mapping(from_icon, to_icon)
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
