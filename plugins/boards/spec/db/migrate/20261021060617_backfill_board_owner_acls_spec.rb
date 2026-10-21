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

    owner_acl = AccessControlList.find_by!(target: board, permission: "owner")
    expect(owner_acl).to have_attributes(
      owner: "boards",
      allowed_user_ids: [creator.id],
      allowed_group_ids: [],
    )
  end

  it "merges the creator into an owner ACL without removing legacy grants" do
    AccessControlList.create!(
      target: board,
      owner: "boards",
      permission: "owner",
      allowed_user_ids: [existing_owner.id],
    )
    manager_acl =
      AccessControlList.create!(
        target: board,
        owner: "boards",
        permission: "manage",
        allowed_user_ids: [creator.id],
      )
    DB.exec("DROP INDEX idx_on_target_type_target_id_permission_f472902150")

    2.times { migrate }

    owner_acl = AccessControlList.find_by!(target: board, permission: "owner")
    expect(owner_acl).to have_attributes(owner: "boards", allowed_group_ids: [])
    expect(owner_acl.allowed_user_ids).to contain_exactly(creator.id, existing_owner.id)
    expect(manager_acl.reload.allowed_user_ids).to eq([creator.id])
  end

  it "does not backfill owner ACLs on a fresh install" do
    DB.exec("UPDATE schema_migration_details SET created_at = NOW()")
    Discourse.clear_site_creation_date_cache

    migrate

    expect(AccessControlList.where(target: board, permission: "owner")).to be_empty
  end
end
