# frozen_string_literal: true

RSpec.describe Boards::ColumnSerializer do
  fab!(:admin)
  fab!(:board) { Fabricate(:boards_board, created_by: admin) }
  fab!(:visible_tag) { Fabricate(:tag, name: "public-roadmap") }
  fab!(:hidden_tag) { Fabricate(:tag, name: "staff-roadmap") }

  before { enable_current_plugin }

  it "serializes core column attributes" do
    column =
      Fabricate(
        :boards_column,
        board:,
        title: "Doing",
        icon: "list-check",
        position: 2,
        default_sort: "recency",
        move_to_category_id: Fabricate(:category).id,
        move_to_assigned: "nobody",
        move_to_status: "closed",
      )

    payload =
      described_class.new(column, root: false, scope: Guardian.new(admin), tag_name_map: {}).as_json

    expect(payload).to include(
      id: column.id,
      title: "Doing",
      icon: "list-check",
      position: 2,
      default_sort: "recency",
      tag_id: nil,
      tag_name: nil,
      move_to_category_id: column.move_to_category_id,
      move_to_assigned: "nobody",
      move_to_status: "closed",
    )
  end

  it "serializes a Unicode column title" do
    column = Fabricate(:boards_column, board:, title: "Doing :rocket:")

    payload =
      described_class.new(column, root: false, scope: Guardian.new(admin), tag_name_map: {}).as_json

    expect(payload).to include(title: "Doing :rocket:", unicode_title: "Doing 🚀")
  end

  it "includes visible tag metadata from the tag name map" do
    column = Fabricate(:boards_column, board:, tag_id: visible_tag.id)

    payload =
      described_class.new(
        column,
        root: false,
        scope: Guardian.new(admin),
        tag_name_map: {
          visible_tag.id => visible_tag.name,
        },
      ).as_json

    expect(payload).to include(tag_id: visible_tag.id, tag_name: visible_tag.name)
  end

  it "omits tag metadata when the tag is not in the tag name map" do
    column = Fabricate(:boards_column, board:, tag_id: hidden_tag.id)

    payload =
      described_class.new(
        column,
        root: false,
        scope: Guardian.new(admin),
        tag_name_map: {
          visible_tag.id => visible_tag.name,
        },
      ).as_json

    expect(payload).to include(tag_id: nil, tag_name: nil)
  end

  it "omits cards unless card context is provided" do
    column = Fabricate(:boards_column, board:)

    payload =
      described_class.new(column, root: false, scope: Guardian.new(admin), tag_name_map: {}).as_json

    expect(payload).not_to have_key(:cards)
  end

  it "serializes cards from the provided cards_by_column context" do
    column = Fabricate(:boards_column, board:)
    first_card =
      Fabricate(
        :boards_card,
        board:,
        column:,
        card_type: :floater,
        title: "First",
        position: 0,
        created_by: admin,
      )
    second_card =
      Fabricate(
        :boards_card,
        board:,
        column:,
        card_type: :floater,
        title: "Second",
        position: 1,
        created_by: admin,
      )

    payload =
      described_class.new(
        column,
        root: false,
        scope: Guardian.new(admin),
        tag_name_map: {
        },
        cards_by_column: {
          column.id => [second_card, first_card],
        },
      ).as_json

    expect(payload[:cards].map { |card| card[:id] }).to eq([first_card.id, second_card.id])
  end
end
