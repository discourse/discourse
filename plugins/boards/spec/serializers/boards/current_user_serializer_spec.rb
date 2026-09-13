# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:user)
  fab!(:edit_group, :group)
  fab!(:board) { Fabricate(:boards_board, slug: "archived-board", archived: true) }

  before do
    enable_current_plugin
    edit_group.add(user)
    Fabricate(
      :access_control_list_with_groups,
      target: board,
      permission: "edit",
      groups: [edit_group],
    )
  end

  describe "#can_edit_any_boards" do
    it "excludes archived boards when determining whether to offer Add to board" do
      payload = described_class.new(user, scope: user.guardian, root: false).as_json

      expect(payload[:can_edit_any_boards]).to eq(false)

      board.update!(archived: false)
      payload = described_class.new(user, scope: user.guardian, root: false).as_json

      expect(payload[:can_edit_any_boards]).to eq(true)
    end
  end
end
