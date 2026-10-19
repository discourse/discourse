# frozen_string_literal: true

RSpec.describe Boards::CreateCard do
  fab!(:admin)
  fab!(:category)
  fab!(:board) do
    Boards::Board.create!(
      name: "Capybara",
      slug: "capybara",
      created_by_id: admin.id,
      category_ids: [category.id],
    )
  end
  fab!(:column) { board.columns.create!(title: "BACKLOG", position: 0) }

  before do
    SiteSetting.capybara_enabled = true
    SiteSetting.boards_enabled = true
    Fabricate(:access_control_list_with_users, target: board, permission: "edit", users: [admin])
  end

  around { |example| stub_const(CodexBoardBot, :BOARD_ID, board.id) { example.run } }

  describe ".call" do
    it "creates a topic with the card description and supports subsequent replies" do
      result =
        described_class.call(
          guardian: admin.guardian,
          params: {
            board_id: board.id,
            column_id: column.id,
            title: "Build a capybara feature",
            notes: "Follow the attached design",
          },
        )
      expect(result).to be_success
      card = result[:card]
      expect(card).to be_topic
      expect(card.topic).to have_attributes(
        title: "Build a capybara feature",
        category_id: category.id,
      )
      expect(card.topic.first_post.raw).to eq("Follow the attached design")
      reply =
        PostCreator.create!(
          admin,
          topic_id: card.topic_id,
          raw: "The updated requirements are here",
          skip_validations: true,
        )
      expect(card.topic.posts).to include(reply)
    end

    it "creates a topic when the optional description is empty" do
      result =
        described_class.call(
          guardian: admin.guardian,
          params: {
            board_id: board.id,
            column_id: column.id,
            title: "Minimal card",
            notes: "",
          },
        )
      expect(result).to be_success
      expect(result[:card].topic.first_post.raw).to eq("Minimal card")
    end

    it "keeps regular cards on another board" do
      other_board = Boards::Board.create!(name: "Other", slug: "other", created_by_id: admin.id)
      Fabricate(
        :access_control_list_with_users,
        target: other_board,
        permission: "edit",
        users: [admin],
      )
      other_column = other_board.columns.create!(title: "TODO", position: 0)
      result =
        described_class.call(
          guardian: admin.guardian,
          params: {
            board_id: other_board.id,
            column_id: other_column.id,
            title: "Regular card",
          },
        )
      expect(result).to be_success
      expect(result[:card]).to be_floater
    end
  end
end
