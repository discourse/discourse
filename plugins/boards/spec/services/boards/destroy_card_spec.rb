# frozen_string_literal: true

RSpec.describe Boards::DestroyCard do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:writer, :user)
    fab!(:reader, :user)
    fab!(:write_group, :group)
    fab!(:read_group, :group)
    fab!(:category) { Fabricate(:category, name: "Boards") }
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:board) do
      board = Boards::Board.create!(name: "Board", slug: "board-dc", created_by_id: admin.id)
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

    let(:dependencies) { { guardian: writer.guardian } }

    before do
      enable_current_plugin
      write_group.add(writer)
      read_group.add(reader)
    end

    context "when destroying a floater card" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Delete",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }

      it { is_expected.to run_successfully }

      it "destroys the card" do
        result
        expect(Boards::Card.find_by(id: card.id)).to be_nil
      end
    end

    context "when destroying a topic card that doesn't match filter" do
      fab!(:card) do
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }

      it { is_expected.to run_successfully }
    end

    context "when topic card is hidden from the user" do
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      fab!(:private_topic) { Fabricate(:topic, category: private_category) }

      fab!(:card) do
        board.cards.create!(
          card_type: :topic,
          topic_id: private_topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }

      it { is_expected.to fail_a_policy(:can_see_card_topic) }
    end

    context "when topic card is covered by board filter" do
      before { board.update!(category_ids: [category.id]) }

      fab!(:card) do
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }

      it { is_expected.to run_successfully }

      it "destroys the card" do
        result
        expect(Boards::Card.find_by(id: card.id)).to be_nil
      end
    end

    context "when card is not found" do
      let(:params) { { board_id: board.id, id: 0 } }

      it { is_expected.to fail_to_find_a_model(:card) }
    end

    context "when user cannot write" do
      fab!(:card) do
        board.cards.create!(
          card_type: :floater,
          title: "Protected",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      let(:params) { { board_id: board.id, id: card.id } }
      let(:dependencies) { { guardian: reader.guardian } }

      it { is_expected.to fail_a_policy(:can_write) }
    end
  end
end
