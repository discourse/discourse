# frozen_string_literal: true

RSpec.describe Boards::Publisher do
  fab!(:admin)
  fab!(:write_group, :group)
  fab!(:read_group, :group)

  before { enable_current_plugin }

  fab!(:board) do
    board =
      Boards::Board.create!(name: "Test Board", slug: "test-publisher", created_by_id: admin.id)
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
  fab!(:column) { board.columns.create!(title: "To Do", position: 0) }
  fab!(:card) do
    board.cards.create!(
      card_type: :floater,
      title: "Test card",
      column_id: column.id,
      position: 0,
      created_by_id: admin.id,
    )
  end

  let(:card_data) { { id: card.id, column_id: column.id, title: "Test card" } }
  let(:channel) { "/boards/#{board.id}" }
  let(:test_client_id) { "abc123" }

  describe ".publish_card_created!" do
    it "publishes a card_created message with group_ids and client_id" do
      messages =
        MessageBus.track_publish(channel) do
          described_class.publish_card_created!(board, card_data, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.data[:type]).to eq("card_created")
      expect(msg.data[:client_id]).to eq(test_client_id)
      expect(msg.data[:card]).to eq(card_data)
      expect(msg.group_ids).to contain_exactly(write_group.id, read_group.id)
    end
  end

  describe ".publish_topic_memberships_changed!" do
    fab!(:topic)

    it "publishes a reload without board membership data" do
      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          described_class.publish_topic_memberships_changed!(topic, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      message = messages.first
      expect(message.data).to eq(reload_topic: true, client_id: test_client_id)
      expect(message.data).not_to have_key(:board_memberships)
    end

    it "optionally refreshes the post stream" do
      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          described_class.publish_topic_memberships_changed!(
            topic,
            client_id: test_client_id,
            refresh_stream: true,
          )
        end

      expect(messages.first.data).to eq(
        reload_topic: true,
        client_id: test_client_id,
        refresh_stream: true,
      )
    end

    context "when the topic is in a private category" do
      fab!(:private_group, :group)
      fab!(:private_category) { Fabricate(:private_category, group: private_group) }
      fab!(:topic) { Fabricate(:topic, category: private_category) }

      it "restricts the reload to the topic's audience" do
        messages =
          MessageBus.track_publish("/topic/#{topic.id}") do
            described_class.publish_topic_memberships_changed!(topic, client_id: test_client_id)
          end

        expect(messages.first.group_ids).to contain_exactly(private_group.id)
      end
    end
  end

  describe ".publish_card_updated!" do
    it "publishes a card_updated message" do
      messages =
        MessageBus.track_publish(channel) do
          described_class.publish_card_updated!(board, card_data, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.data[:type]).to eq("card_updated")
      expect(messages.first.data[:card]).to eq(card_data)
    end
  end

  describe ".publish_card_moved!" do
    it "publishes a card_moved message" do
      messages =
        MessageBus.track_publish(channel) do
          described_class.publish_card_moved!(board, card_data, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.data[:type]).to eq("card_moved")
      expect(messages.first.data[:card]).to eq(card_data)
    end
  end

  describe ".publish_card_deleted!" do
    it "publishes a card_deleted message with card_id" do
      messages =
        MessageBus.track_publish(channel) do
          described_class.publish_card_deleted!(board, card.id, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.data[:type]).to eq("card_deleted")
      expect(msg.data[:client_id]).to eq(test_client_id)
      expect(msg.data[:card_id]).to eq(card.id)
    end
  end

  describe ".publish_board_updated!" do
    it "publishes a board_updated message" do
      messages =
        MessageBus.track_publish(channel) do
          described_class.publish_board_updated!(board, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.data[:type]).to eq("board_updated")
      expect(msg.data[:client_id]).to eq(test_client_id)
    end
  end

  context "with a public board" do
    fab!(:public_board) do
      Boards::Board.create!(
        name: "Public Board",
        slug: "test-publisher-public",
        created_by_id: admin.id,
      )
    end

    it "publishes without group_ids restriction" do
      messages =
        MessageBus.track_publish("/boards/#{public_board.id}") do
          described_class.publish_board_updated!(public_board, client_id: test_client_id)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.group_ids).to be_nil
    end
  end
end
