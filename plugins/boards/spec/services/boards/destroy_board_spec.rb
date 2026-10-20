# frozen_string_literal: true

RSpec.describe Boards::DestroyBoard do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:manager, :user)
    fab!(:outsider, :user)
    fab!(:manage_group, :group)
    fab!(:board) do
      Boards::Board.create!(name: "Delete Me", slug: "delete-me", created_by_id: admin.id)
    end

    let(:params) { { id: board.id } }
    let(:dependencies) { { guardian: manager.guardian } }

    before do
      enable_current_plugin
      SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
      manage_group.add(manager)
    end

    context "when contract is invalid" do
      let(:params) { { id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when board is not found" do
      let(:params) { { id: 0 } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when user cannot destroy the board based on the ACL" do
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_destroy) }
    end

    context "when everything is valid" do
      before do
        Fabricate(
          :access_control_list_with_groups,
          target: board,
          permission: "manage",
          groups: [manage_group],
        )
      end

      it { is_expected.to run_successfully }

      it "destroys the board" do
        result
        expect(Boards::Board.find_by(id: board.id)).to be_nil
      end

      it "creates a board deletion history" do
        result
        expect(board.history.first).to have_attributes(
          action: "board_deleted",
          acting_user_id: manager.id,
          board_id: board.id,
        )
      end
    end
  end
end
