# frozen_string_literal: true

require Rails.root.join(
          "plugins/boards/db/post_migrate/20261021060627_finalize_board_owner_acls.rb",
        )

RSpec.describe FinalizeBoardOwnerAcls do
  subject(:migrate) { described_class.new.up }

  fab!(:creator, :user)
  fab!(:existing_owner, :user)
  fab!(:member, :user)
  fab!(:group)
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
    unless connection.column_exists?(:access_control_lists, :source)
      connection.add_column(:access_control_lists, :source, :string, limit: 100)
    end
    connection.change_column_null(:access_control_lists, :source, true)
    connection.change_column_null(:access_control_lists, :owner, true)
    DB.exec("UPDATE schema_migration_details SET created_at = NOW() - INTERVAL '2 hours'")
    Discourse.clear_site_creation_date_cache
  end

  after do
    ActiveRecord::Migration.verbose = @original_verbose
    Discourse.clear_site_creation_date_cache
  end

  it "preserves established ownership and removes grants redundant with current owners" do
    AccessControlList.create!(
      target: board,
      source: "boards",
      permission: "owner",
      allowed_user_ids: [existing_owner.id],
    )
    AccessControlList.create!(
      target: board,
      source: "boards",
      permission: "manage",
      allowed_user_ids: [creator.id, existing_owner.id],
    )
    edit_acl =
      AccessControlList.create!(
        target: board,
        source: "boards",
        permission: "edit",
        allowed_user_ids: [creator.id, existing_owner.id, member.id],
      )
    view_acl =
      AccessControlList.create!(
        target: board,
        source: "boards",
        permission: "view",
        allowed_user_ids: [creator.id],
        allowed_group_ids: [group.id],
      )

    2.times { migrate }

    owner_acl = AccessControlList.find_by!(target: board, permission: "owner")
    expect(owner_acl.allowed_user_ids).to eq([existing_owner.id])
    expect(AccessControlList.find_by!(target: board, permission: "manage").allowed_user_ids).to eq(
      [creator.id],
    )
    expect(edit_acl.reload.allowed_user_ids).to contain_exactly(creator.id, member.id)
    expect(view_acl.reload).to have_attributes(
      allowed_user_ids: [creator.id],
      allowed_group_ids: [group.id],
    )
  end

  it "catches boards created during rollout before cleaning up the creator's direct grants" do
    manager_acl =
      AccessControlList.create!(
        target: board,
        source: "boards",
        permission: "manage",
        allowed_user_ids: [creator.id, member.id],
      )
    DB.exec("DROP INDEX idx_on_target_type_target_id_permission_f472902150")

    migrate

    expect(AccessControlList.find_by!(target: board, permission: "owner").allowed_user_ids).to eq(
      [creator.id],
    )
    expect(manager_acl.reload.allowed_user_ids).to eq([member.id])
  end

  it "does not backfill or clean up ACLs on a fresh install" do
    manager_acl =
      AccessControlList.create!(
        target: board,
        source: "boards",
        permission: "manage",
        allowed_user_ids: [creator.id],
      )
    DB.exec("UPDATE schema_migration_details SET created_at = NOW()")
    Discourse.clear_site_creation_date_cache

    migrate

    expect(AccessControlList.where(target: board, permission: "owner")).to be_empty
    expect(manager_acl.reload.allowed_user_ids).to eq([creator.id])
  end
end
