# frozen_string_literal: true

require Rails.root.join(
          "plugins/boards/db/migrate/20260901020329_migrate_discourse_kanban_to_boards.rb",
        )

RSpec.describe MigrateDiscourseKanbanToBoards do
  subject(:migrate) { described_class.new.up }

  fab!(:creator, :user)
  fab!(:board) do
    Boards::Board.create!(name: "Migration board", slug: "migration-board", created_by: creator)
  end
  fab!(:group)

  around do |example|
    original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    example.run
  ensure
    ActiveRecord::Migration.verbose = original_verbose
    Discourse.clear_site_creation_date_cache
  end

  def mark_as_existing_site
    DB.exec("UPDATE schema_migration_details SET created_at = NOW() - INTERVAL '2 hours'")
    Discourse.clear_site_creation_date_cache
  end

  def insert_setting(name:, value:, data_type:)
    DB.exec(<<~SQL, name:, value:, data_type:)
      INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
      VALUES (:name, :value, :data_type, NOW(), NOW())
    SQL
  end

  def insert_acl(target_type:, permission:, owner:)
    AccessControlList.create!(
      target_id: board.id,
      target_type:,
      permission:,
      owner:,
      allowed_group_ids: [group.id],
    )
  end

  it "copies legacy settings on existing sites without removing or overwriting values" do
    mark_as_existing_site
    insert_setting(name: "discourse_kanban_enabled", value: "t", data_type: 5)
    insert_setting(
      name: "discourse_kanban_manage_board_allowed_groups",
      value: "1|42",
      data_type: 20,
    )
    insert_setting(name: "boards_enabled", value: "f", data_type: 5)

    2.times { migrate }

    settings = DB.query(<<~SQL).map { |setting| [setting.name, setting.value, setting.data_type] }
          SELECT name, value, data_type
          FROM site_settings
          WHERE name IN (
            'boards_enabled',
            'boards_manage_board_allowed_groups',
            'discourse_kanban_enabled',
            'discourse_kanban_manage_board_allowed_groups'
          )
        SQL

    expect(settings).to contain_exactly(
      ["boards_enabled", "f", 5],
      ["boards_manage_board_allowed_groups", "1|42", 20],
      ["discourse_kanban_enabled", "t", 5],
      ["discourse_kanban_manage_board_allowed_groups", "1|42", 20],
    )
  end

  it "does not copy legacy settings on fresh installs" do
    DB.exec("UPDATE schema_migration_details SET created_at = NOW()")
    Discourse.clear_site_creation_date_cache
    insert_setting(name: "discourse_kanban_enabled", value: "t", data_type: 5)

    migrate

    setting_names = DB.query_single("SELECT name FROM site_settings")
    expect(setting_names).not_to include("boards_enabled")
    expect(setting_names).to include("discourse_kanban_enabled")
  end

  it "copies legacy ACLs to the Boards model while preserving the legacy rows" do
    %w[view edit manage].each do |permission|
      insert_acl(target_type: "DiscourseKanban::Board", permission:, owner: "discourse-kanban")
    end

    2.times { migrate }

    expect(
      AccessControlList.where(target_id: board.id).pluck(
        :target_type,
        :owner,
        :permission,
        :allowed_group_ids,
      ),
    ).to contain_exactly(
      ["DiscourseKanban::Board", "discourse-kanban", "view", [group.id]],
      ["DiscourseKanban::Board", "discourse-kanban", "edit", [group.id]],
      ["DiscourseKanban::Board", "discourse-kanban", "manage", [group.id]],
      ["Boards::Board", "boards", "view", [group.id]],
      ["Boards::Board", "boards", "edit", [group.id]],
      ["Boards::Board", "boards", "manage", [group.id]],
    )
  end

  it "copies legacy ACLs idempotently when the expected unique index is absent" do
    insert_acl(target_type: "DiscourseKanban::Board", permission: "view", owner: "discourse-kanban")
    DB.exec("DROP INDEX idx_on_target_type_target_id_permission_f472902150")

    2.times { migrate }

    expect(
      AccessControlList.where(
        target_id: board.id,
        target_type: "Boards::Board",
        permission: "view",
      ).pluck(:owner, :allowed_group_ids),
    ).to eq([["boards", [group.id]]])
  end

  it "does not overwrite an existing Boards ACL when copying a legacy row" do
    legacy =
      insert_acl(
        target_type: "DiscourseKanban::Board",
        permission: "view",
        owner: "discourse-kanban",
      )
    existing = insert_acl(target_type: "Boards::Board", permission: "view", owner: "core")

    migrate

    expect(legacy.reload).to have_attributes(
      target_type: "DiscourseKanban::Board",
      owner: "discourse-kanban",
    )
    expect(existing.reload).to have_attributes(target_type: "Boards::Board", owner: "core")
    expect(AccessControlList.where(target_id: board.id, permission: "view").count).to eq(2)
  end
end
