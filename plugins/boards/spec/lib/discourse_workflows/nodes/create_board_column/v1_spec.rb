# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::CreateBoardColumn::V1 do
  fab!(:admin)
  fab!(:manager, :user)
  fab!(:manage_group, :group)
  fab!(:board) do
    Fabricate(:boards_board, name: "Project board", additional_manage_groups: [manage_group])
  end

  before do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.boards_enabled = true
    SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
    manage_group.add(manager)
  end

  it "registers an available per-item action with a dynamic board selector" do
    expect(described_class.identifier).to eq("action:create_board_column")
    expect(described_class.description).to include(
      version: "1.0",
      group: "discourse_actions",
      defaults: {
        icon: "rectangle-list",
        color: "light-green",
      },
      capabilities: {
        run_scope: "per_item",
      },
    )
    expect(DiscourseWorkflows::PropertySchemaValidator.validate_node(described_class)).to be_empty
    expect(described_class.property_schema[:board_id]).to include(
      required: true,
      type: :integer,
      type_options: {
        load_options_method: "boards",
      },
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

    it "lists only boards the configuring user can manage" do
      other_board = Fabricate(:boards_board)

      expect(load_options).to eq([{ id: board.id, name: board.name }])
      expect(load_options(user: admin)).to contain_exactly(
        { id: board.id, name: board.name },
        { id: other_board.id, name: other_board.name },
      )
    end

    it "filters board names case-insensitively" do
      Fabricate(:boards_board, name: "Other", additional_manage_groups: [manage_group])

      expect(load_options(filter: "PROJECT")).to eq([{ id: board.id, name: board.name }])
      expect(load_options(filter: "missing")).to be_empty
    end
  end

  describe "#execute" do
    let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => {} }) }
    let(:configuration) { { "board_id" => board.id, "title" => "Backlog" } }

    after { sandbox.dispose }

    def execute_node(config = configuration, user: manager, items: [{ "json" => {} }])
      resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox:)
      context =
        DiscourseWorkflows::Executor::NodeExecutionContext.new(
          input_items: items,
          user:,
          resolver:,
          parameters: config,
          property_schema: described_class.property_schema,
        )
      described_class
        .new(parameters: config)
        .execute(context)
        .first
        .map { |item| item.fetch("json") }
    end

    it "creates a column with defaults and returns exactly its id and title" do
      output = execute_node.first
      column = Boards::Column.find(output.fetch("column_id"))

      expect(column).to have_attributes(
        board_id: board.id,
        title: "Backlog",
        default_sort: "priority",
        icon: nil,
        color: nil,
        tag_id: nil,
      )
      expect(output).to eq("column_id" => column.id, "title" => column.title)
      expect(output).to match_node_output_schema(described_class)
      expect(board.history.sole).to have_attributes(action: "column_added", acting_user: manager)
    end

    it "uses the system user when there is no execution user" do
      execute_node(user: nil)

      expect(board.history.sole.acting_user).to eq(Discourse.system_user)
    end

    it "passes optional values and normalizes picker colors for the service" do
      tag = Fabricate(:tag)
      output =
        execute_node(
          configuration.merge(
            "icon" => "check",
            "color" => "#1A2B3C",
            "tag_name" => tag.name,
            "default_sort" => "recency",
          ),
        ).first

      expect(Boards::Column.find(output.fetch("column_id"))).to have_attributes(
        icon: "check",
        color: "1A2B3C",
        tag_id: tag.id,
        default_sort: "recency",
      )
    end

    it "treats empty optional values as unset" do
      output =
        execute_node(
          configuration.merge("icon" => "", "color" => "", "tag_name" => "", "default_sort" => ""),
        ).first

      expect(Boards::Column.find(output.fetch("column_id"))).to have_attributes(
        icon: nil,
        color: nil,
        tag_id: nil,
        default_sort: "priority",
      )
    end

    it "resolves the board id and title for each input item" do
      other_board = Fabricate(:boards_board, additional_manage_groups: [manage_group])
      items = [
        { "json" => { "board_id" => board.id, "title" => "First" } },
        { "json" => { "board_id" => other_board.id, "title" => "Second" } },
      ]

      outputs =
        execute_node(
          { "board_id" => "={{ $json.board_id }}", "title" => "={{ $json.title }}" },
          items:,
        )

      expect(outputs.pluck("title")).to eq(%w[First Second])
      expect(
        outputs.map { |output| Boards::Column.find(output.fetch("column_id")).board_id },
      ).to eq([board.id, other_board.id])
      outputs.each { |output| expect(output).to match_node_output_schema(described_class) }
    end

    it "rejects unauthorized execution users without creating a column" do
      expect do
        expect { execute_node(user: Fabricate(:user)) }.to raise_error(
          DiscourseWorkflows::NodeError,
          I18n.t("discourse_workflows.errors.create_board_column.forbidden"),
        )
      end.not_to change { Boards::Column.count }
    end

    it "reports a missing board as a node error" do
      expect { execute_node(configuration.merge("board_id" => 0)) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.create_board_column.board_not_found"),
      )
    end

    it "reports invalid title and color as node errors" do
      [{ "title" => "" }, { "color" => "purple" }].each do |invalid_params|
        expect { execute_node(configuration.merge(invalid_params)) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /Could not create board column/,
        )
      end
    end

    it "reports invalid sort and unknown tags as node errors" do
      [
        [
          { "default_sort" => "random" },
          I18n.t("boards.errors.invalid_column_sort", sort: "random"),
        ],
        [
          { "tag_name" => "missing-tag" },
          I18n.t("boards.errors.unknown_tag_name", tag_name: "missing-tag"),
        ],
      ].each do |invalid_params, error|
        expect { execute_node(configuration.merge(invalid_params)) }.to raise_error(
          DiscourseWorkflows::NodeError,
          I18n.t("discourse_workflows.errors.create_board_column.invalid_params", errors: error),
        )
      end
    end

    it "reports duplicate column tags without creating another column" do
      tag = Fabricate(:tag)
      config = configuration.merge("tag_name" => tag.name)
      execute_node(config)

      expect do
        expect { execute_node(config) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /#{Regexp.escape(I18n.t("boards.errors.cannot_use_same_tag_multiple_times", tag_name: tag.name))}/,
        )
      end.not_to change { Boards::Column.count }
    end
  end
end
