# frozen_string_literal: true

RSpec.describe Boards::DestroyColumn do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:manager, :user)
    fab!(:outsider, :user)
    fab!(:manage_group, :group)
    fab!(:board) do
      Fabricate(:boards_board, created_by: admin, additional_manage_groups: [manage_group])
    end
    fab!(:first_column) { board.columns.create!(title: "First", position: 0) }
    fab!(:column) { board.columns.create!(title: "Second", position: 1) }
    fab!(:third_column) { board.columns.create!(title: "Third", position: 2) }

    let(:params) { { board_id: board.id, id: column.id } }
    let(:dependencies) { { guardian: manager.guardian } }

    before do
      enable_current_plugin
      SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
      manage_group.add(manager)
    end

    context "when contract is invalid" do
      let(:params) { { board_id: board.id, id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, id: column.id } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when column is not found" do
      let(:params) { { board_id: board.id, id: 0 } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when user cannot manage boards" do
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_manage) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "deletes the column and its cards" do
        card =
          board.cards.create!(
            card_type: :floater,
            title: "Card",
            column_id: column.id,
            position: 0,
            created_by_id: admin.id,
          )

        result

        expect(Boards::Column.exists?(column.id)).to eq(false)
        expect(Boards::Card.exists?(card.id)).to eq(false)
      end

      it "compacts remaining column positions" do
        result

        expect(first_column.reload.position).to eq(0)
        expect(third_column.reload.position).to eq(1)
      end

      it "tracks the column deleted history" do
        result

        expect(board.history.last).to have_attributes(
          action: "column_deleted",
          acting_user_id: manager.id,
          board_id: board.id,
          column_id: column.id,
          details: {
            "title" => "Second",
          },
        )
      end

      it "publishes a board_updated event" do
        messages = MessageBus.track_publish("/boards/#{board.id}") { result }

        expect(messages.map { |message| message.data[:type] }).to include("board_updated")
      end
    end
  end
end
