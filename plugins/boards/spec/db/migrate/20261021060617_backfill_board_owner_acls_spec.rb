# frozen_string_literal: true

require Rails.root.join("plugins/boards/db/migrate/20261021060617_backfill_board_owner_acls.rb")

RSpec.describe BackfillBoardOwnerAcls do
  subject(:migrate) { described_class.new.up }

  fab!(:creator, :user)
  fab!(:existing_owner, :user)
  fab!(:board) do
    Boards::Board.create!(
      name: "Owner migration board",
      slug: "owner-migration",
      created_by: creator,
    )
  end

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    connection = ActiveRecord::Base.connection
    if connection.column_exists?(:access_control_lists, :source)
      connection.remove_column(:access_control_lists, :source)
    end
    DB.exec("UPDATE schema_migration_details SET created_at = NOW() - INTERVAL '2 hours'")
    Discourse.clear_site_creation_date_cache
  end

  after do
    ActiveRecord::Migration.verbose = @original_verbose
    Discourse.clear_site_creation_date_cache
  end

  it "creates an owner ACL for the board creator idempotently" do
    DB.exec("DROP INDEX idx_on_target_type_target_id_permission_f472902150")

    2.times { migrate }

    expect(DB.query_single(<<~SQL, target_id: board.id)).to eq(["boards", [creator.id], []])
        SELECT owner, allowed_user_ids, allowed_group_ids
        FROM access_control_lists
        WHERE target_type = 'Boards::Board'
          AND target_id = :target_id
          AND permission = 'owner'
      SQL
  end

  def insert_acl(permission:, user_ids:)
    DB.query_single(<<~SQL, target_id: board.id, permission:, user_id: user_ids.first)
        INSERT INTO access_control_lists (
          target_type,
          target_id,
          owner,
          permission,
          allowed_user_ids,
          created_at,
          updated_at
        )
        VALUES (
          'Boards::Board',
          :target_id,
          'boards',
          :permission,
          ARRAY[:user_id]::bigint[],
          NOW(),
          NOW()
        )
        RETURNING id
      SQL
  end

  it "preserves established ownership and the creator's legacy grant" do
    insert_acl(permission: "owner", user_ids: [existing_owner.id])
    manager_acl_id = insert_acl(permission: "manage", user_ids: [creator.id]).first
    DB.exec("DROP INDEX idx_on_target_type_target_id_permission_f472902150")

    2.times { migrate }

    owner_acl = DB.query(<<~SQL, target_id: board.id).first
        SELECT owner, allowed_user_ids, allowed_group_ids
        FROM access_control_lists
        WHERE target_type = 'Boards::Board'
          AND target_id = :target_id
          AND permission = 'owner'
      SQL
    expect(owner_acl.owner).to eq("boards")
    expect(owner_acl.allowed_user_ids).to eq([existing_owner.id])
    expect(owner_acl.allowed_group_ids).to eq([])
    expect(
      DB.query_single(
        "SELECT allowed_user_ids FROM access_control_lists WHERE id = :id",
        id: manager_acl_id,
      ).first,
    ).to eq([creator.id])
  end

  it "does not backfill owner ACLs on a fresh install" do
    DB.exec("UPDATE schema_migration_details SET created_at = NOW()")
    Discourse.clear_site_creation_date_cache

    migrate

    expect(DB.query_single(<<~SQL, target_id: board.id).first).to eq(0)
        SELECT COUNT(*)
        FROM access_control_lists
        WHERE target_type = 'Boards::Board'
          AND target_id = :target_id
          AND permission = 'owner'
      SQL
  end
end
