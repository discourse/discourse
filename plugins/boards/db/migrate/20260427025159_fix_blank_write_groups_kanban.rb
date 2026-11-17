# frozen_string_literal: true
class FixBlankWriteGroupsKanban < ActiveRecord::Migration[8.0]
  def up
    discourse_kanban_manage_board_allowed_groups =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'discourse_kanban_manage_board_allowed_groups'",
      ).first

    if discourse_kanban_manage_board_allowed_groups.blank?
      discourse_kanban_manage_board_allowed_groups = "3" # site setting default
    end

    group_ids = discourse_kanban_manage_board_allowed_groups.split("|").map(&:to_i)

    execute <<~SQL
      UPDATE discourse_kanban_boards
      SET allow_write_group_ids = ARRAY[#{group_ids.join(",")}]::integer[]
      WHERE allow_write_group_ids IS NULL OR allow_write_group_ids = '{}'::integer[]
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
