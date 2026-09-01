# frozen_string_literal: true

class MigrateDiscourseKanbanToBoards < ActiveRecord::Migration[8.0]
  SITE_SETTING_NAMES = {
    "discourse_kanban_enabled" => "boards_enabled",
    "discourse_kanban_manage_board_allowed_groups" => "boards_manage_board_allowed_groups",
  }.freeze

  def up
    copy_site_settings if Migration::Helpers.existing_site?
    copy_access_control_lists
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def copy_site_settings
    SITE_SETTING_NAMES.each { |old_name, new_name| DB.exec(<<~SQL, old_name:, new_name:) }
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        SELECT :new_name, data_type, value, created_at, updated_at
        FROM site_settings
        WHERE name = :old_name
        ON CONFLICT (name) DO NOTHING
      SQL
  end

  def copy_access_control_lists
    execute <<~SQL
      INSERT INTO access_control_lists (
        target_type,
        target_id,
        owner,
        permission,
        allowed_user_ids,
        allowed_group_ids,
        created_at,
        updated_at
      )
      SELECT
        'Boards::Board',
        target_id,
        CASE
          WHEN owner = 'discourse-kanban' THEN 'boards'
          ELSE owner
        END,
        permission,
        allowed_user_ids,
        allowed_group_ids,
        created_at,
        updated_at
      FROM access_control_lists
      WHERE target_type = 'DiscourseKanban::Board'
      ON CONFLICT (target_type, target_id, permission) DO NOTHING
    SQL
  end
end
