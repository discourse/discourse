# frozen_string_literal: true

RSpec.describe Boards::ViewBoard do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:reader, :user)
    fab!(:outsider, :user)
    fab!(:read_group, :group)
    fab!(:write_group, :group)
    fab!(:board) do
      board = Boards::Board.create!(name: "Board", slug: "board-view", created_by_id: admin.id)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [write_group],
      )
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [read_group],
      )
      board
    end

    let(:params) { { id: board.id } }
    let(:dependencies) { { guardian: reader.guardian } }

    before do
      enable_current_plugin
      read_group.add(reader)
    end

    context "when user is not logged in" do
      let(:dependencies) { { guardian: Guardian.new } }

      it { is_expected.to fail_a_policy(:is_logged_in) }
    end

    context "when board is not found" do
      let(:params) { { id: 0 } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when board was already viewed today" do
      before { Boards::BoardHistory.create!(board:, acting_user: reader, action: :board_viewed) }

      it { is_expected.to run_successfully }

      it "does not create a duplicate history record" do
        expect { result }.not_to change {
          Boards::BoardHistory.where(action: :board_viewed, board_id: board.id).count
        }
      end
    end

    context "when user cannot read the board" do
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_read_board) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a board view history record" do
        expect { result }.to change {
          Boards::BoardHistory.where(action: :board_viewed, board_id: board.id).count
        }.by(1)
        expect(
          Boards::BoardHistory.where(action: :board_viewed, board_id: board.id).last,
        ).to have_attributes(acting_user_id: reader.id, board_id: board.id)
      end
    end
  end
end
