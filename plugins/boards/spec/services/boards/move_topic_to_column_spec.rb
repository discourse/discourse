# frozen_string_literal: true

RSpec.describe Boards::MoveTopicToColumn do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:to_column_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:writer, :user)
    fab!(:reader, :user)
    fab!(:write_group, :group)
    fab!(:read_group, :group)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category, user: writer) }
    fab!(:board) do
      board = Boards::Board.create!(name: "Board", slug: "board-mtc", created_by_id: admin.id)
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
    fab!(:column) { board.columns.create!(title: "Doing", position: 0) }
    fab!(:recency_column) do
      board.columns.create!(title: "Recent", position: 1, default_sort: "recency")
    end

    let(:channel) { "/boards/#{board.id}" }
    let(:client_id) { "test-123" }
    let(:messages) { MessageBus.track_publish(channel) { result } }
    let(:params) do
      { board_id: board.id, topic_id: topic.id, to_column_id: column.id, client_id: client_id }
    end
    let(:dependencies) { { guardian: admin.guardian } }

    before do
      enable_current_plugin
      write_group.add(writer)
      write_group.add(admin)
      read_group.add(reader)
    end

    context "when contract is invalid" do
      let(:params) { { board_id: board.id } }

      it { is_expected.to fail_a_contract }
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, topic_id: topic.id, to_column_id: column.id } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when user cannot write to board" do
      let(:dependencies) { { guardian: reader.guardian } }

      it { is_expected.to fail_a_policy(:can_write) }
    end

    context "when topic is not found" do
      let(:params) { { board_id: board.id, topic_id: 0, to_column_id: column.id } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when user cannot see topic" do
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      fab!(:private_topic) { Fabricate(:topic, category: private_category) }

      let(:params) { { board_id: board.id, topic_id: private_topic.id, to_column_id: column.id } }
      let(:dependencies) { { guardian: writer.guardian } }

      it { is_expected.to fail_a_policy(:can_see_topic) }
    end

    context "when user cannot edit topic" do
      fab!(:other_user, :user)

      let(:dependencies) { { guardian: other_user.guardian } }

      before { write_group.add(other_user) }

      it { is_expected.to fail_a_policy(:can_edit_topic) }
    end

    context "when column is not found" do
      let(:params) { { board_id: board.id, topic_id: topic.id, to_column_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when topic has no existing card" do
      it { is_expected.to run_successfully }

      it "creates a topic card on the column" do
        expect(result[:card]).to be_previously_new_record.and have_attributes(
                                       topic_id: topic.id,
                                       column_id: column.id,
                                       card_type: "topic",
                                     )
      end

      it "sets creator and updater to the acting user" do
        expect(result[:card]).to have_attributes(created_by_id: admin.id, updated_by_id: admin.id)
      end

      it "sets column_changed_at" do
        expect(result[:card].column_changed_at).to be_present
      end

      it "publishes a card_created event scoped to board read groups" do
        expect(messages).to contain_exactly(
          have_attributes(
            data:
              include(
                type: "card_created",
                client_id: client_id,
                card: include(topic_id: topic.id),
              ),
            group_ids: contain_exactly(write_group.id, read_group.id),
          ),
        )
      end
    end

    context "when topic already has a card on the column" do
      fab!(:existing_card) do
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: writer.id,
        )
      end

      it { is_expected.to run_successfully }

      it "returns the existing card" do
        expect(result[:card]).not_to be_previously_new_record
        expect(result[:card]).to have_attributes(id: existing_card.id, created_by_id: writer.id)
      end

      it "publishes a card_moved event" do
        expect(messages).to contain_exactly(
          have_attributes(data: include(type: "card_moved", client_id: client_id)),
        )
      end
    end

    context "when moving a topic to a column sorted by recency" do
      let(:params) do
        {
          board_id: board.id,
          topic_id: topic.id,
          to_column_id: recency_column.id,
          after_card_id: existing_card.id,
          client_id: client_id,
        }
      end

      fab!(:existing_card) do
        other_topic = Fabricate(:topic, category: category)
        board.cards.create!(
          card_type: :topic,
          topic_id: other_topic.id,
          column_id: recency_column.id,
          position: 0,
          created_by_id: writer.id,
        )
      end

      it "places the new card at the beginning" do
        expect(result[:card].position).to be < existing_card.reload.position
        expect(result[:card].column_changed_at).to be_present
      end
    end

    context "when column has a tag_id mutation" do
      fab!(:tag) { Fabricate(:tag, name: "in-progress") }

      before { column.update!(tag_id: tag.id) }

      it "applies the tag to the topic" do
        result
        expect(topic.reload.tags.map(&:name)).to include("in-progress")
      end
    end
  end
end
