# frozen_string_literal: true

RSpec.describe Boards::OneboxHandler do
  fab!(:admin)

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

  fab!(:topic) { Fabricate(:topic, title: "Topic card headline") }

  fab!(:column) { board.columns.create!(title: "Todo", position: 0) }
  fab!(:tag_1, :tag)
  fab!(:tag_2, :tag)
  fab!(:category) { Fabricate(:category, name: "events", slug: "events") }

  fab!(:floater_card) do
    board.cards.create!(
      card_type: :floater,
      title: "Standalone card title",
      column_id: column.id,
      position: 0,
      created_by_id: admin.id,
      tag_ids: [tag_1.id, tag_2.id],
      notes: "This is **markdown** _note_",
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

  describe "card onebox" do
    it "returns empty string if the card does not exist" do
      floater_card.destroy!
      expect(
        Boards::OneboxHandler.handle(floater_card.url, { id: board.id, card_id: floater_card.id }),
      ).to eq("")
    end

    it "returns empty string if the user does not have permission to read the board" do
      private_group = Fabricate(:group)
      board.access_control_lists.destroy_all
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [private_group],
      )
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [private_group],
      )
      expect(
        Boards::OneboxHandler.handle(floater_card.url, { id: board.id, card_id: floater_card.id }),
      ).to eq("")
    end

    it "does not expose the title of a topic the viewer cannot read" do
      private_group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: private_group)
      private_topic =
        Fabricate(:topic, title: "Restricted topic card headline", category: private_category)
      topic_card.update!(topic: private_topic)

      onebox_html =
        Boards::OneboxHandler.handle(topic_card.url, { id: board.id, card_id: topic_card.id })

      expect(onebox_html).to eq("")
    end

    it "renders a restricted topic card onebox for an authorized same-category context" do
      private_group = Fabricate(:group)
      private_user = Fabricate(:user)
      Fabricate(:group_user, group: private_group, user: private_user)
      private_category = Fabricate(:private_category, group: private_group)
      private_topic =
        Fabricate(:topic, title: "Restricted topic card headline", category: private_category)
      topic_card.update!(topic: private_topic)

      onebox_html =
        Boards::OneboxHandler.handle(
          topic_card.url,
          { id: board.id, card_id: topic_card.id },
          { user_id: private_user.id, category_id: private_category.id },
        )

      expect(onebox_html).to include(private_topic.title)
    end

    it "does not return empty string if the onebox renders successfully" do
      expect(
        Boards::OneboxHandler.handle(floater_card.url, { id: board.id, card_id: floater_card.id }),
      ).not_to eq("")
    end

    it "renders emoji codes in the column title as Unicode" do
      column.update!(title: "Todo :rocket:")

      onebox_html =
        Boards::OneboxHandler.handle(floater_card.url, { id: board.id, card_id: floater_card.id })

      expect(onebox_html).to include("Todo 🚀")
      expect(onebox_html).not_to include(":rocket:")
    end

    it "renders emoji codes in the card title as Unicode" do
      floater_card.update!(title: "Launch :rocket:")

      onebox_html =
        Boards::OneboxHandler.handle(floater_card.url, { id: board.id, card_id: floater_card.id })

      expect(onebox_html).to include("Launch 🚀")
      expect(onebox_html).not_to include(":rocket:")
    end

    it "has the correct HTML structure" do
      onebox_html =
        Boards::OneboxHandler.handle(floater_card.url, { id: board.id, card_id: floater_card.id })

      expect(onebox_html).to have_tag(
        "a",
        with: {
          class: "discourse-boards-card__title",
          href: floater_card.url,
        },
        seen: floater_card.resolved_title,
      )

      expect(onebox_html).to have_tag(
        "a",
        with: {
          class: "discourse-boards-board-pill",
          href: board.url,
        },
        seen: board.name,
      )

      expect(onebox_html).to have_tag(
        "span",
        with: {
          class: "discourse-boards-column-pill",
        },
        seen: column.title,
      )

      expect(onebox_html).to have_tag("div", with: { class: "discourse-boards-card__tags" })

      floater_card.tags.each do |tag|
        expect(onebox_html).to have_tag(
          "a",
          with: {
            class: "hashtag-cooked",
            "data-slug": tag.name,
          },
          seen: tag.name,
        )
      end

      expect(onebox_html).to have_tag(
        "div",
        with: {
          class: "discourse-boards-card__notes",
        },
        seen: "This is markdown note",
      )

      expect(onebox_html).to have_tag(
        "span",
        with: {
          class: "relative-date",
          "data-time": (floater_card.updated_at.to_f * 1000).to_i,
          "data-format": "tiny",
        },
      )

      expect(onebox_html).to include(
        "(#{floater_card.updated_by&.username || floater_card.created_by.username})",
      )
      expect(onebox_html).to have_tag("aside", with: { class: "onebox" })
    end

    it "handles nil opts gracefully for a topic card" do
      onebox_html =
        Boards::OneboxHandler.handle(topic_card.url, { id: board.id, card_id: topic_card.id }, nil)

      expect(onebox_html).to include(topic_card.resolved_title)
    end
  end

  describe "board onebox" do
    it "returns empty string if the board does not exist" do
      board.destroy!
      expect(Boards::OneboxHandler.handle(board.url, { id: board.id })).to eq("")
    end

    it "returns empty string if the user does not have permission to read the board" do
      private_group = Fabricate(:group)
      board.access_control_lists.destroy_all
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [private_group],
      )
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [private_group],
      )
      expect(Boards::OneboxHandler.handle(board.url, { id: board.id })).to eq("")
    end

    it "does not return empty string if the onebox renders successfully" do
      expect(Boards::OneboxHandler.handle(board.url, { id: board.id })).not_to eq("")
    end

    it "renders emoji codes in the board name as Unicode" do
      board.update!(name: "Roadmap :rocket:")

      onebox_html = Boards::OneboxHandler.handle(board.url, { id: board.id })

      expect(onebox_html).to include("Roadmap 🚀")
      expect(onebox_html).not_to include(":rocket:")
    end

    it "renders emoji codes in column titles as Unicode" do
      column.update!(title: "Todo :rocket:")

      onebox_html = Boards::OneboxHandler.handle(board.url, { id: board.id })

      expect(onebox_html).to include("Todo 🚀")
      expect(onebox_html).not_to include(":rocket:")
    end

    it "has the correct HTML structure" do
      board.update!(tag_ids: [tag_1.id, tag_2.id], category_ids: [category.id])

      onebox_html = Boards::OneboxHandler.handle(board.url, { id: board.id })

      expect(onebox_html).to have_tag("aside", with: { class: "onebox" })

      expect(onebox_html).to have_tag(
        "a",
        with: {
          class: "discourse-boards-board-card__name",
          href: board.url,
        },
        seen: board.name,
      )

      expect(onebox_html).to have_tag(
        "div",
        with: {
          class: "discourse-boards-board-card__constraints",
        },
      )
      expect(onebox_html).to have_tag("div", with: { class: "list-tags" })

      board.tags.each do |tag|
        expect(onebox_html).to have_tag(
          "a",
          with: {
            class: "hashtag-cooked",
            "data-slug": tag.name,
          },
          seen: tag.name,
        )
      end

      board.categories.each do |board_category|
        expect(onebox_html).to have_tag(
          "a",
          with: {
            class: "hashtag-cooked",
            "data-slug": board_category.slug,
          },
          seen: board_category.name,
        )
      end

      expect(onebox_html).to have_tag(
        "div",
        with: {
          class: "discourse-boards-board-card__columns",
        },
      )

      board.columns.each do |board_column|
        expect(onebox_html).to have_tag(
          "span",
          with: {
            class: "discourse-boards-column-pill",
          },
          seen: board_column.title,
        )
      end

      expect(onebox_html).to have_tag(
        "a",
        with: {
          class: "discourse-boards-board-card__creator discourse-boards-badge trigger-user-card",
          "data-user-card": admin.username,
        },
        seen: I18n.t("boards.onebox.created_by", username: admin.display_name),
      )

      expect(onebox_html).to have_tag(
        "span",
        with: {
          class: "discourse-boards-badge",
        },
        seen: I18n.t("boards.onebox.column_count", count: board.columns.count),
      )
    end

    context "when the board is restricted" do
      fab!(:private_group, :group)

      before do
        board.access_control_lists.destroy_all
        Fabricate(
          :access_control_list_with_groups,
          target: board,
          permission: "view",
          groups: [private_group],
        )
        Fabricate(
          :access_control_list_with_groups,
          target: board,
          permission: "edit",
          groups: [private_group],
        )
      end

      it "returns an empty string" do
        expect(Boards::OneboxHandler.handle(board.url, { id: board.id })).to eq("")
      end
    end
  end
end
