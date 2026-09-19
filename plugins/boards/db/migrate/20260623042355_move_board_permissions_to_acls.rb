# frozen_string_literal: true

class MoveBoardPermissionsToAcls < ActiveRecord::Migration[8.0]
  def up
    original_board_permissions = DB.query(<<~SQL)
      SELECT id, allow_read_group_ids, allow_write_group_ids
      FROM discourse_kanban_boards
    SQL

    kanban_manage_group_ids = DB.query_single(<<~SQL).first
      SELECT value FROM site_settings WHERE name = 'discourse_kanban_manage_board_allowed_groups'
    SQL

    if kanban_manage_group_ids.blank?
      kanban_manage_group_ids = [1] # admins only by default/mandatory
    else
      kanban_manage_group_ids = (kanban_manage_group_ids.split("|").map(&:to_i) + [1]).uniq # ensure admins are always included
    end

    target_type = "DiscourseKanban::Board"
    owner = "discourse-kanban"
    now = Time.zone.now
    logged_in_users_group_id = 5 # Group::AUTO_GROUPS[:logged_in_users]

    rows = []
    original_board_permissions.each do |bp|
      # Previously empty read groups meant "public", but for this migration we
      # want to err on the side of caution and grant logged in users only when
      # none were specified. Board owners can add the anonymous users group back
      # later if they need to.
      read_group_ids = bp.allow_read_group_ids.presence || [logged_in_users_group_id]
      rows << { target_id: bp.id, permission: "view", group_ids: read_group_ids }

      if bp.allow_write_group_ids.present?
        rows << { target_id: bp.id, permission: "edit", group_ids: bp.allow_write_group_ids }
      end

      rows << { target_id: bp.id, permission: "manage", group_ids: kanban_manage_group_ids }
    end

    return if rows.empty?

    DB.exec(
      <<~SQL,
        INSERT INTO access_control_lists
          (target_id, target_type, owner, permission, allowed_group_ids, created_at, updated_at)
        SELECT t.target_id, :target_type, :owner, t.permission, t.group_ids::bigint[], :now, :now
        FROM unnest(
          ARRAY[:target_ids]::bigint[],
          ARRAY[:permissions]::text[],
          ARRAY[:group_ids]::text[]
        ) AS t(target_id, permission, group_ids)
        ON CONFLICT (target_id, target_type, permission) DO NOTHING
      SQL
      target_ids: rows.map { |r| r[:target_id] },
      permissions: rows.map { |r| r[:permission] },
      group_ids: rows.map { |r| "{#{r[:group_ids].join(",")}}" },
      target_type: target_type,
      owner: owner,
      now: now,
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
