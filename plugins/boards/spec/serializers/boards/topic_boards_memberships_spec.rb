# frozen_string_literal: true

RSpec.describe Boards::TopicBoardMembershipSerializer do
  fab!(:admin)
  fab!(:reader, :user)
  fab!(:read_group, :group)
  fab!(:topic)

  fab!(:board) do
    Fabricate(:boards_board, name: "Sales :dollar_banknote:", slug: "sales", created_by: admin)
  end
  fab!(:column) do
    Fabricate(
      :boards_column,
      board:,
      title: "In progress :hourglass_done:",
      position: 0,
      color: "0088cc",
      icon: "angles-up",
    )
  end
  fab!(:card) { Fabricate(:boards_topic_card, board:, column:, topic:) }

  before do
    enable_current_plugin
    read_group.add(reader)
    Fabricate(
      :access_control_list_with_groups,
      target: board,
      permission: "view",
      groups: [read_group],
    )
  end

  let(:list_item_json) do
    ->(user) { TopicListItemSerializer.new(topic, scope: Guardian.new(user), root: false).as_json }
  end

  let(:topic_view_json) do
    lambda do |user|
      TopicViewSerializer.new(
        TopicView.new(topic, user),
        scope: Guardian.new(user),
        root: false,
      ).as_json
    end
  end

  describe "topic list item serializer" do
    it "includes memberships for users who can read the board" do
      expect(list_item_json.call(reader)[:board_memberships]).to eq(
        [
          {
            board_id: board.id,
            board_name: "Sales :dollar_banknote:",
            board_slug: "sales",
            unicode_board_name: "Sales 💵",
            cards: [
              {
                card_id: card.id,
                column_id: column.id,
                column_title: "In progress :hourglass_done:",
                column_color: "0088cc",
                column_icon: "angles-up",
                unicode_column_title: "In progress ⌛",
              },
            ],
          },
        ],
      )
    end

    it "includes a Unicode column title" do
      column.update!(title: "In progress :rocket:")

      membership = list_item_json.call(reader)[:board_memberships].sole

      expect(membership[:cards].sole).to include(
        column_title: "In progress :rocket:",
        unicode_column_title: "In progress 🚀",
      )
    end

    it "includes a Unicode board name" do
      board.update!(name: "Sales :fire:")

      membership = list_item_json.call(reader)[:board_memberships].sole

      expect(membership).to include(board_name: "Sales :fire:", unicode_board_name: "Sales 🔥")
    end

    it "omits memberships for users who cannot read the board" do
      other_user = Fabricate(:user)
      expect(list_item_json.call(other_user)).not_to have_key(:board_memberships)
    end

    it "omits the attribute when the plugin is disabled" do
      SiteSetting.boards_enabled = false
      expect(list_item_json.call(reader)).not_to have_key(:board_memberships)
    end

    it "omits the attribute for topics without cards" do
      card.destroy!
      topic.board_cards_map = nil
      expect(list_item_json.call(reader)).not_to have_key(:board_memberships)
    end

    it "groups multiple topic cards from the same board into one membership" do
      second_column = Fabricate(:boards_column, board:, title: "Done", position: 1, color: "00aa66")
      second_card = Fabricate(:boards_topic_card, board:, column: second_column, topic:)

      membership = list_item_json.call(reader)[:board_memberships].sole

      expect(membership[:board_id]).to eq(board.id)
      expect(membership[:cards].pluck(:card_id)).to eq([card.id, second_card.id])
    end

    it "uses preloaded cards when present" do
      result =
        Boards::TopicBoardMemberships.call(guardian: reader.guardian, options: { topics: [topic] })
      topic.board_cards_map = result[:cards_map].fetch(topic.id)
      expect(topic.board_cards_map.fetch(board.id).map(&:id)).to eq([card.id])

      queries =
        track_sql_queries { list_item_json.call(reader) }.select { |q| q.include?("boards_cards") }
      expect(queries).to be_empty
    end

    it "batches board ACL checks across topics" do
      topics =
        2.times.map do |index|
          extra_topic = Fabricate(:topic)
          extra_board = Fabricate(:boards_board, name: "Board #{index}", created_by: admin)
          extra_column = Fabricate(:boards_column, board: extra_board, position: 0)
          Fabricate(
            :boards_topic_card,
            board: extra_board,
            column: extra_column,
            topic: extra_topic,
          )
          Fabricate(
            :access_control_list_with_groups,
            target: extra_board,
            permission: "view",
            groups: [read_group],
          )
          extra_topic
        end
      topics.unshift(topic)
      topic_list = TopicList.new("latest", reader, topics)

      acl_queries =
        track_sql_queries { TopicList.preload(topics, topic_list) }.select do |query|
          query.include?("access_control_lists")
        end

      expect(acl_queries.size).to eq(1)
      expect(topics).to all(satisfy { |listed_topic| listed_topic.board_cards_map.present? })
    end

    it "does not run ACL queries while serializing a preloaded topic list" do
      topics =
        2.times.map do
          extra_topic = Fabricate(:topic)
          Fabricate(:boards_topic_card, board:, column:, topic: extra_topic)
          extra_topic
        end
      topics.unshift(topic)
      TopicList.preload(topics, TopicList.new("latest", reader, topics))

      acl_queries =
        track_sql_queries do
          topics.each do |listed_topic|
            TopicListItemSerializer.new(
              listed_topic,
              scope: Guardian.new(reader),
              root: false,
            ).as_json
          end
        end.select { |query| query.include?("access_control_lists") }

      expect(acl_queries).to be_empty
    end
  end

  describe "topic view serializer" do
    it "includes memberships for users who can read the board" do
      memberships = topic_view_json.call(reader)[:board_memberships]
      expect(memberships.flat_map { |membership| membership[:cards] }.pluck(:card_id)).to eq(
        [card.id],
      )
    end

    it "returns an empty membership list for users who cannot read the board" do
      other_user = Fabricate(:user)
      expect(topic_view_json.call(other_user)[:board_memberships]).to eq([])
    end

    it "returns an empty membership list when the last card is removed" do
      card.destroy!

      expect(topic_view_json.call(reader)[:board_memberships]).to eq([])
    end

    it "omits the attribute when the plugin is disabled" do
      SiteSetting.boards_enabled = false

      expect(topic_view_json.call(reader)).not_to have_key(:board_memberships)
    end
  end
end
