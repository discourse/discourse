# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::CreateBoard::V1 do
  fab!(:manager, :moderator)
  fab!(:group)

  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => {} }) }
  let(:configuration) do
    {
      "name" => "Project board",
      "acl" => [{ "type" => "group", "id" => group.id, "permission" => "manage" }],
    }
  end

  before do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.boards_enabled = true
  end

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
    described_class.new(parameters: config).execute(context).first.map { |item| item.fetch("json") }
  end

  it "registers a per-item Discourse action with a declarative ACL control" do
    expect(described_class.identifier).to eq("action:create_board")
    expect(described_class.description).to include(
      version: "1.0",
      group: "discourse_actions",
      defaults: {
        icon: "boards",
        color: "light-green",
      },
      capabilities: {
        run_scope: "per_item",
      },
    )
    expect(DiscourseWorkflows::PropertySchemaValidator.validate_node(described_class)).to be_empty
    expect(described_class.property_schema[:acl]).to include(
      required: true,
      type: :object,
      ui: {
        control: :access_control,
        expression: false,
      },
      control_options: {
        acl_target_type: "Boards::Board",
        acl_target_key: Boards::Board.acl_target_key,
        acl_target_name: "boards.manage.board",
        permissions: %w[view edit manage],
      },
    )
    expect(described_class).to be_available
    SiteSetting.boards_enabled = false
    expect(described_class).not_to be_available
  end

  it "creates a board with an explicit slug as the execution user" do
    output = execute_node(configuration.merge("slug" => "custom-board")).first
    board = Boards::Board.find(output.fetch("board_id"))

    expect(board).to have_attributes(
      name: "Project board",
      slug: "custom-board",
      created_by: manager,
    )
    expect(output).to eq("board_id" => board.id, "slug" => board.slug)
    expect(output).to match_node_output_schema(described_class)
    expect(board.history.sole).to have_attributes(action: "board_created", acting_user: manager)
    expect(board.permission_acl.permission_group_ids("manage")).to contain_exactly(
      group.id,
      Group::AUTO_GROUPS[:admins],
    )
  end

  it "generates a slug and uses the system user when no execution user is present" do
    output = execute_node(user: nil).first
    board = Boards::Board.find(output.fetch("board_id"))

    expect(board).to have_attributes(slug: "project-board", created_by: Discourse.system_user)
    expect(output).to match_node_output_schema(described_class)
  end

  it "passes tag names, categories, and flattened permissions to board creation" do
    tag = Fabricate(:tag)
    category = Fabricate(:category)
    config =
      configuration.merge(
        "tag_names" => [tag.name],
        "category_ids" => [category.id],
        "acl" =>
          configuration["acl"] +
            [
              {
                "type" => "group",
                "id" => Group::AUTO_GROUPS[:logged_in_users],
                "permission" => "view",
              },
            ],
      )

    output = execute_node(config).first
    board = Boards::Board.find(output.fetch("board_id"))

    expect(board.tag_ids).to eq([tag.id])
    expect(board.category_ids).to eq([category.id])
    expect(board.permission_acl.permission_group_ids("view")).to eq(
      [Group::AUTO_GROUPS[:logged_in_users]],
    )
    expect(output).to match_node_output_schema(described_class)
  end

  it "resolves the name separately for each input item" do
    config = configuration.merge("name" => "={{ $json.name }}")
    items = [{ "json" => { "name" => "First board" } }, { "json" => { "name" => "Second board" } }]

    outputs = execute_node(config, items:)

    expect(outputs.pluck("slug")).to eq(%w[first-board second-board])
    expect(outputs.pluck("board_id").uniq.size).to eq(2)
    outputs.each { |output| expect(output).to match_node_output_schema(described_class) }
  end

  it "resolves group access separately for each item and preserves fixed permissions" do
    other_group = Fabricate(:group)
    config =
      configuration.merge(
        "name" => "={{ $json.name }}",
        "acl" => {
          "entries" => configuration["acl"],
          "group_ids" => "={{ $json.group_ids }}",
          "permission" => "edit",
        },
      )
    items = [
      {
        "json" => {
          "name" => "First",
          "group_ids" => [group.id, other_group.id, other_group.id],
        },
      },
      { "json" => { "name" => "Second", "group_ids" => [] } },
    ]

    boards = execute_node(config, items:).map { |output| Boards::Board.find(output["board_id"]) }

    expect(boards.first.permission_acl.permission_group_ids("edit")).to eq([other_group.id])
    expect(boards.first.permission_acl.permission_group_ids("manage")).to contain_exactly(
      group.id,
      Group::AUTO_GROUPS[:admins],
    )
    expect(boards.last.permission_acl.permission_group_ids("edit")).to be_empty
  end

  it "rejects automatic input groups before creating a board" do
    config =
      configuration.merge(
        "acl" => {
          "entries" => configuration["acl"],
          "group_ids" => "={{ $json.group_ids }}",
          "permission" => "manage",
        },
      )
    items = [{ "json" => { "group_ids" => [Group::AUTO_GROUPS[:anonymous_users]] } }]

    expect do
      expect { execute_node(config, items:) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.access_control.missing_groups"),
      )
    end.not_to change { Boards::Board.count }
  end

  it "rejects unauthorized execution users without creating a board" do
    expect do
      expect { execute_node(user: Fabricate(:user)) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.create_board.forbidden"),
      )
    end.not_to change { Boards::Board.count }
  end

  it "reports contract failures as node errors" do
    expect { execute_node(configuration.merge("name" => "")) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /Could not create board:.*Name/,
    )
  end

  it "reports model validation failures as node errors" do
    execute_node

    expect { execute_node }.to raise_error(
      DiscourseWorkflows::NodeError,
      /Slug has already been taken/,
    )
  end

  it "reports tag resolution failures as node errors" do
    SiteSetting.tagging_enabled = true
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
    user = Fabricate(:user)
    group.add(user)
    SiteSetting.boards_manage_board_allowed_groups = group.id.to_s

    expect do
      execute_node(configuration.merge("tag_names" => ["missing-tag"]), user:)
    end.to raise_error(DiscourseWorkflows::NodeError, /Unknown tag names: missing-tag/)
  end

  it "reports banned ACL failures and rolls back board creation" do
    config =
      configuration.merge(
        "acl" => [
          {
            "type" => "group",
            "id" => Group::AUTO_GROUPS[:anonymous_users],
            "permission" => "manage",
          },
        ],
      )

    expect do
      expect { execute_node(config) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.create_board.acl_failed"),
      )
    end.not_to change { Boards::Board.count }
  end
end
