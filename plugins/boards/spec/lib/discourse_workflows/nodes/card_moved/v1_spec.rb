# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::CardMoved::V1 do
  fab!(:admin)
  fab!(:manager, :user)
  fab!(:manage_group, :group)
  fab!(:board) do
    Fabricate(:boards_board, name: "Project board", additional_manage_groups: [manage_group])
  end
  fab!(:old_column) { Fabricate(:boards_column, board:, title: "Backlog") }
  fab!(:new_column) { Fabricate(:boards_column, board:, title: "Done") }
  fab!(:card) { Fabricate(:boards_card, board:, column: new_column) }

  before do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.boards_enabled = true
    SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
    manage_group.add(manager)
  end

  it "registers an available card moved trigger with an optional board selector" do
    expect(described_class.identifier).to eq("trigger:card_moved")
    expect(described_class.description).to include(
      version: "1.0",
      group: "discourse_triggers",
      event: :boards_card_moved,
      defaults: {
        icon: "arrow-right",
        color: "light-green",
      },
      capabilities: {
        provides_current_user: true,
      },
    )
    expect(DiscourseWorkflows::PropertySchemaValidator.validate_node(described_class)).to be_empty
    expect(described_class.property_schema[:board_id]).to include(
      type: :integer,
      required: false,
      type_options: {
        load_options_method: "boards",
      },
      no_data_expression: true,
    )
    expect(described_class.property_schema[:board_id][:ui]).to include(control: :combo_box)

    expect(described_class).to be_available
    SiteSetting.boards_enabled = false
    expect(described_class).not_to be_available
  end

  describe ".load_options_context" do
    def load_options(user: manager, filter: nil)
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "boards",
          user:,
          guardian: user.guardian,
          filter:,
          node_class: described_class,
        )
      described_class.load_options_context(context)
    end

    it "lists and filters only boards the configuring user can manage" do
      other_board = Fabricate(:boards_board, name: "Other board")
      managed_board =
        Fabricate(:boards_board, name: "Project archive", additional_manage_groups: [manage_group])

      expect(load_options).to contain_exactly(
        { id: board.id, name: board.name },
        { id: managed_board.id, name: managed_board.name },
      )
      expect(load_options(filter: "PROJECT")).to contain_exactly(
        { id: board.id, name: board.name },
        { id: managed_board.id, name: managed_board.name },
      )
      expect(load_options(user: admin)).to contain_exactly(
        { id: board.id, name: board.name },
        { id: managed_board.id, name: managed_board.name },
        { id: other_board.id, name: other_board.name },
      )
    end
  end

  describe "#matches?" do
    subject(:trigger) do
      described_class.new(
        board,
        { id: card.id, old_column_id: old_column.id, column_id: new_column.id },
        manager,
      )
    end

    def trigger_context(board_id = nil)
      DiscourseWorkflows::TriggerNodeContext.new(
        "parameters" => board_id.nil? ? {} : { "board_id" => board_id },
      )
    end

    it "matches every board when no scope is configured" do
      expect(trigger.matches?(trigger_context)).to eq(true)
    end

    it "matches only the configured board" do
      expect(trigger.matches?(trigger_context(board.id))).to eq(true)
      expect(trigger.matches?(trigger_context(Fabricate(:boards_board).id))).to eq(false)
    end

    it "returns card and column data that conforms to the output schema" do
      expect(trigger.output).to match_node_output_schema(described_class)
      expect(trigger.output).to include(
        card: include("id" => card.id, "board_id" => board.id, "column_id" => new_column.id),
        card_moved: {
          old_column: include("id" => old_column.id, "board_id" => board.id),
          new_column: include("id" => new_column.id, "board_id" => board.id),
        },
        acting_user: include(id: manager.id, username: manager.username),
      )
      expect(trigger.user_id).to eq(manager.id)
    end
  end
end
