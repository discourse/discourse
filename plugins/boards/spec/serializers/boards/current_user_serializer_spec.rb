# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:user)
  fab!(:edit_group, :group)
  fab!(:board, :boards_board)

  let(:payload) { described_class.new(user, scope: user.guardian, root: false).as_json }

  before do
    enable_current_plugin
    edit_group.add(user)
    SiteSetting.boards_manage_board_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
  end

  it "omits all board permissions when boards are disabled" do
    SiteSetting.boards_enabled = false

    expect(payload.keys).not_to include(
      :can_manage_boards,
      :can_edit_any_boards,
      :can_see_any_boards,
    )
  end

  it "returns false for all board permissions when the user has no access" do
    expect(payload).to include(
      can_manage_boards: false,
      can_edit_any_boards: false,
      can_see_any_boards: false,
    )
  end

  describe "#can_manage_boards" do
    it "grants global management independently of access to existing boards" do
      SiteSetting.boards_manage_board_allowed_groups = edit_group.id.to_s

      expect(payload).to include(
        can_manage_boards: true,
        can_edit_any_boards: false,
        can_see_any_boards: false,
      )
    end
  end

  describe "board ACL permissions" do
    it "grants visibility for a View grant" do
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [edit_group],
      )

      expect(payload).to include(
        can_manage_boards: false,
        can_edit_any_boards: false,
        can_see_any_boards: true,
      )
    end

    it "grants visibility and editing for an Edit grant" do
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [edit_group],
      )

      expect(payload).to include(
        can_manage_boards: false,
        can_edit_any_boards: true,
        can_see_any_boards: true,
      )
    end

    it "grants visibility and editing for a Manage grant" do
      acl = AccessControlList.find_by!(target: board, permission: "manage")
      acl.update!(allowed_group_ids: acl.allowed_group_ids + [edit_group.id])

      expect(payload).to include(
        can_manage_boards: false,
        can_edit_any_boards: true,
        can_see_any_boards: true,
      )
    end

    it "grants visibility and editing to the board owner" do
      Fabricate(:boards_board, created_by: user)

      expect(payload).to include(
        can_manage_boards: false,
        can_edit_any_boards: true,
        can_see_any_boards: true,
      )
    end
  end

  describe "#can_edit_any_boards" do
    it "excludes archived boards when determining whether to offer Add to board" do
      board.update!(archived: true)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [edit_group],
      )
      payload = described_class.new(user, scope: user.guardian, root: false).as_json

      expect(payload).to include(can_edit_any_boards: false, can_see_any_boards: false)

      board.update!(archived: false)
      payload = described_class.new(user, scope: user.guardian, root: false).as_json

      expect(payload).to include(can_edit_any_boards: true, can_see_any_boards: true)
    end
  end

  describe "#can_see_any_boards" do
    it "excludes archived boards even when the user has view access" do
      board.update!(archived: true)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [edit_group],
      )

      expect(payload[:can_see_any_boards]).to eq(false)
    end

    it "returns false when there are no boards" do
      board.destroy!

      expect(payload).to include(can_edit_any_boards: false, can_see_any_boards: false)
    end
  end
end
