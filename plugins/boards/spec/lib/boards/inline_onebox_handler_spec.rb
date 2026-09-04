# frozen_string_literal: true

RSpec.describe Boards::InlineOneboxHandler do
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, title: "Topic card headline") }

  before { enable_current_plugin }

  fab!(:board) do
    board =
      Boards::Board.create!(name: "Roadmap board", slug: "roadmap-board", created_by_id: admin.id)
    Fabricate(
      :access_control_list,
      target: board,
      permission: "view",
      allowed_group_ids: [
        Group::AUTO_GROUPS[:anonymous_users],
        Group::AUTO_GROUPS[:logged_in_users],
      ],
    )
    board
  end

  fab!(:column) { board.columns.create!(title: "Todo", position: 0) }

  fab!(:floater_card) do
    board.cards.create!(
      card_type: :floater,
      title: "Standalone card title",
      column_id: column.id,
      position: 0,
      created_by_id: admin.id,
    )
  end

  fab!(:topic_card) do
    board.cards.create!(
      card_type: :topic,
      topic_id: topic.id,
      column_id: column.id,
      position: 1,
      created_by_id: admin.id,
    )
  end

  let(:base_url) { "https://example.com/boards-plugin-path" }

  let(:route_board_only) { { id: board.id.to_s, card_id: nil } }
  let(:floater_card_route) { { id: board.id.to_s, card_id: floater_card.id.to_s } }
  let(:topic_card_route) { { id: board.id.to_s, card_id: topic_card.id.to_s } }

  describe ".handle" do
    context "when the route has no card id" do
      it "handles nil opts gracefully" do
        result = described_class.handle("#{base_url}/boards/x/#{board.id}", route_board_only, nil)
        expect(result).to eq(
          url: "#{base_url}/boards/x/#{board.id}",
          title: I18n.t("boards.onebox.inline_to_board", board_name: board.name),
        )
      end

      it "returns url and a board title when the board exists and is readable" do
        result = described_class.handle("#{base_url}/boards/x/#{board.id}", route_board_only)

        expect(result).to eq(
          url: "#{base_url}/boards/x/#{board.id}",
          title: I18n.t("boards.onebox.inline_to_board", board_name: board.name),
        )
      end

      it "renders emoji codes in the board title as Unicode" do
        board.update!(name: "Roadmap :rocket:")

        result = described_class.handle("#{base_url}/boards/x/#{board.id}", route_board_only)

        expect(result[:title]).to eq("Board 'Roadmap 🚀'")
      end

      it "returns nil when the board does not exist" do
        missing_id = Boards::Board.maximum(:id).to_i + 99_999
        route = { id: missing_id.to_s, card_id: nil }

        expect(described_class.handle("#{base_url}/boards/x/#{missing_id}", route)).to be_nil
      end

      it "returns nil when the guardian denies board read access" do
        private_group = Fabricate(:group)
        board.access_control_lists.destroy_all
        Fabricate(
          :access_control_list_with_groups,
          target: board,
          permission: "view",
          groups: [private_group],
        )
        expect(
          described_class.handle("#{base_url}/boards/x/#{board.id}", route_board_only),
        ).to be_nil
      end
    end

    context "when the route includes a card id" do
      it "returns url and a card title using the floater card name" do
        result =
          described_class.handle(
            "#{base_url}/boards/x/#{board.id}/cards/#{floater_card.id}",
            floater_card_route,
          )

        expect(result).to eq(
          url: "#{base_url}/boards/x/#{board.id}/cards/#{floater_card.id}",
          title:
            I18n.t(
              "boards.onebox.inline_to_card",
              card_name: floater_card.resolved_title,
              board_name: board.name,
            ),
        )
      end

      it "renders emoji codes in card and board titles as Unicode" do
        board.update!(name: "Roadmap :rocket:")
        floater_card.update!(title: "Launch :tada:")

        result =
          described_class.handle(
            "#{base_url}/boards/x/#{board.id}/cards/#{floater_card.id}",
            floater_card_route,
          )

        expect(result[:title]).to eq("Card 'Launch 🎉' on board 'Roadmap 🚀'")
      end

      it "uses the topic title for topic-backed cards" do
        result =
          described_class.handle(
            "#{base_url}/boards/x/#{board.id}/cards/#{topic_card.id}",
            topic_card_route,
          )

        expect(result).to eq(
          url: "#{base_url}/boards/x/#{board.id}/cards/#{topic_card.id}",
          title:
            I18n.t(
              "boards.onebox.inline_to_card",
              card_name: "Topic card headline",
              board_name: board.name,
            ),
        )
      end

      it "handles nil opts gracefully for topic backed cards" do
        result =
          described_class.handle(
            "#{base_url}/boards/x/#{board.id}/cards/#{topic_card.id}",
            topic_card_route,
            nil,
          )

        expect(result).to eq(
          url: "#{base_url}/boards/x/#{board.id}/cards/#{topic_card.id}",
          title:
            I18n.t(
              "boards.onebox.inline_to_card",
              card_name: "Topic card headline",
              board_name: board.name,
            ),
        )
      end

      it "does not expose the title of a topic the viewer cannot read" do
        private_group = Fabricate(:group)
        private_category = Fabricate(:private_category, group: private_group)
        private_topic =
          Fabricate(:topic, title: "Restricted topic card headline", category: private_category)
        topic_card.update!(topic: private_topic)

        expect(
          described_class.handle(
            "#{base_url}/boards/x/#{board.id}/cards/#{topic_card.id}",
            topic_card_route,
          ),
        ).to be_nil
      end

      it "returns the card title for an authorized same-category context" do
        private_group = Fabricate(:group)
        private_user = Fabricate(:user)
        Fabricate(:group_user, group: private_group, user: private_user)
        private_category = Fabricate(:private_category, group: private_group)
        private_topic =
          Fabricate(:topic, title: "Restricted topic card headline", category: private_category)
        topic_card.update!(topic: private_topic)

        result =
          described_class.handle(
            "#{base_url}/boards/x/#{board.id}/cards/#{topic_card.id}",
            topic_card_route,
            { user_id: private_user.id, category_id: private_category.id },
          )

        expect(result).to eq(
          url: "#{base_url}/boards/x/#{board.id}/cards/#{topic_card.id}",
          title:
            I18n.t(
              "boards.onebox.inline_to_card",
              card_name: private_topic.title,
              board_name: board.name,
            ),
        )
      end

      it "returns nil when the board does not exist" do
        missing_board_id = Boards::Board.maximum(:id).to_i + 99_999
        route = { id: missing_board_id.to_s, card_id: floater_card.id.to_s }

        expect(
          described_class.handle(
            "#{base_url}/boards/x/#{missing_board_id}/cards/#{floater_card.id}",
            route,
          ),
        ).to be_nil
      end

      it "returns nil when the guardian denies board read access" do
        private_group = Fabricate(:group)
        board.access_control_lists.destroy_all
        Fabricate(
          :access_control_list_with_groups,
          target: board,
          permission: "view",
          groups: [private_group],
        )
        expect(
          described_class.handle(
            "#{base_url}/boards/x/#{board.id}/cards/#{floater_card.id}",
            floater_card_route,
          ),
        ).to be_nil
      end

      it "returns nil when no card matches the id and board id" do
        other_board =
          Boards::Board.create!(name: "Other", slug: "other-board", created_by_id: admin.id)
        route = { id: other_board.id.to_s, card_id: floater_card.id.to_s }

        expect(
          described_class.handle(
            "#{base_url}/boards/x/#{other_board.id}/cards/#{floater_card.id}",
            route,
          ),
        ).to be_nil
      end

      it "returns nil when the card id does not exist" do
        missing_card_id = Boards::Card.maximum(:id).to_i + 99_999
        route = { id: board.id.to_s, card_id: missing_card_id.to_s }

        expect(
          described_class.handle(
            "#{base_url}/boards/x/#{board.id}/cards/#{missing_card_id}",
            route,
          ),
        ).to be_nil
      end
    end
  end
end
