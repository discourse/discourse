# frozen_string_literal: true

RSpec.describe Boards::ViewCard do
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
    fab!(:column) { board.columns.create!(title: "Col", position: 0) }
    fab!(:card) do
      board.cards.create!(
        card_type: :floater,
        title: "View Me",
        column_id: column.id,
        position: 0,
        created_by_id: admin.id,
      )
    end

    let(:params) { { id: card.id } }
    let(:dependencies) { { guardian: reader.guardian } }

    before do
      enable_current_plugin
      read_group.add(reader)
    end

    context "when user is not logged in" do
      let(:dependencies) { { guardian: Guardian.new } }

      it { is_expected.to fail_a_policy(:is_logged_in) }
    end

    context "when card is not found" do
      before { card.destroy! }

      it { is_expected.to fail_to_find_a_model(:card) }
    end

    context "when user cannot view the card" do
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_view_card) }
    end

    context "when view history was already recorded today" do
      before do
        Boards::CardHistory.create!(
          card:,
          acting_user: reader,
          action: :card_viewed,
          board_id: board.id,
        )
      end

      it { is_expected.to run_successfully }

      it "does not create a duplicate history record" do
        expect { result }.not_to change {
          Boards::CardHistory.where(action: :card_viewed, card_id: card.id).count
        }
      end
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a card view history record" do
        expect { result }.to change {
          Boards::CardHistory.where(action: :card_viewed, card_id: card.id).count
        }.by(1)
      end

      it "records the acting user and board" do
        result
        history = Boards::CardHistory.where(action: :card_viewed, card_id: card.id).last
        expect(history).to have_attributes(acting_user_id: reader.id, board_id: board.id)
      end
    end
  end
end
