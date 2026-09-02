# frozen_string_literal: true

describe "Add topic to board from topic footer menu" do
  fab!(:admin)
  fab!(:viewer, :user)
  fab!(:view_group, :group)
  fab!(:original_category, :category)
  fab!(:target_category, :category)
  fab!(:topic) { Fabricate(:topic_with_op, category: original_category) }
  fab!(:product_board) { Fabricate(:boards_board, name: "Product", column_names: %w[Backlog Done]) }
  fab!(:engineering_board) do
    Fabricate(:boards_board, name: "Engineering", column_names: ["Doing"])
  end
  fab!(:roadmap_board) do
    Fabricate(
      :boards_board,
      name: "Roadmap",
      column_names: ["Next"],
      category_ids: [target_category.id],
    )
  end
  fab!(:product_board_view_acl) do
    Fabricate(
      :access_control_list_with_groups,
      target: product_board,
      permission: "view",
      groups: [view_group],
    )
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:add_from_topic) { PageObjects::Components::BoardsAddFromTopic.new }
  let(:category_badge) { PageObjects::Components::CategoryBadge.new }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:constraint_modal) do
    PageObjects::Modals::Base.new(body_selector: ".discourse-boards-constraint-fix-modal")
  end

  before { enable_current_plugin }

  context "when logged in" do
    it "adds the topic to a board column" do
      column = product_board.columns.first

      sign_in(admin)
      topic_page.visit_topic(topic)
      add_from_topic.add_to_column(product_board, column)

      expect(add_from_topic).to have_membership(product_board, column)
      expect(product_board.cards.topic.find_by(topic: topic, column: column)).to be_present
    end

    it "removes the topic from a board column" do
      column = product_board.columns.first
      card = Fabricate(:boards_topic_card, board: product_board, column:, topic:)

      sign_in(admin)
      topic_page.visit_topic(topic)
      expect(add_from_topic).to have_membership(product_board, column)

      add_from_topic.remove_from_column(product_board, column)

      expect(toasts).to have_success(
        I18n.t(
          "js.boards.board.removed_topic_from_board",
          boardName: product_board.unicode_name,
          columnName: column.unicode_title,
        ),
      )
      expect(Boards::Card).not_to exist(card.id)
    end

    xit "fixes constraints and updates the topic header through MessageBus" do
      existing_column = engineering_board.columns.first
      Fabricate(:boards_topic_card, board: engineering_board, column: existing_column, topic: topic)
      target_column = roadmap_board.columns.first

      sign_in(admin)
      topic_page.visit_topic(topic)
      expect(add_from_topic).to have_membership(engineering_board, existing_column)

      add_from_topic.add_to_column(roadmap_board, target_column)

      expect(constraint_modal).to be_open
      constraint_modal.click_primary_button

      expect(topic.reload.category).to eq(target_category)
      within("#topic-title") { category_badge.find_for_category(target_category) }
      expect(add_from_topic).to have_membership_count(2)

      add_from_topic.open_memberships
      expect(add_from_topic).to have_membership_in_menu(engineering_board, existing_column)
      expect(add_from_topic).to have_membership_in_menu(roadmap_board, target_column)
    end

    it "hides the button from users without edit or manage access to any board" do
      view_group.add(viewer)
      sign_in(viewer)

      topic_page.visit_topic(topic)

      expect(add_from_topic).to have_no_add_to_board_button
    end
  end

  context "when anonymous" do
    it "hides the button" do
      topic_page.visit_topic(topic)

      expect(add_from_topic).to have_no_add_to_board_button
    end
  end
end
