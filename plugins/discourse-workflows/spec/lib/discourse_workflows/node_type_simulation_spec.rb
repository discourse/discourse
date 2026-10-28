# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeType, "#execute_simulation" do
  around do |example|
    nodes_before = described_class.registered_nodes.dup
    example.run
    described_class.registered_nodes.replace(nodes_before)
  end

  def build_context(node_class, parameters:, input_items:, resolver_spy: nil)
    resolver_context = { "$json" => input_items.first&.dig("json") || {} }
    sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context, user: nil)
    resolver =
      DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox, user: nil)
    ctx =
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items: input_items,
        resolver: resolver,
        parameters: parameters,
        credentials: {
        },
        property_schema: node_class.property_schema,
        credential_schema: node_class.credentials,
        node_identifier: node_class.identifier,
        node_name: "Step under test",
        resolver_context: resolver_context,
        execution_mode: :simulation,
      )
    resolver_spy&.call(ctx)
    [ctx, resolver, sandbox]
  end

  let(:operation_node) do
    Class.new(described_class) do
      description(
        name: "action:simulation_spec_operations",
        version: "1.0",
        properties: {
          operation: {
            type: :options,
            options: %w[get edit purge],
            default: "get",
          },
          target: {
            type: :string,
          },
        },
      )

      simulation do
        pure "get"
        supported "edit"
        unsupported "purge"
      end

      def resolve_config(exec_ctx, item:, item_index:, operation:)
        { "target" => exec_ctx.get_node_parameter("target", item_index) }
      end

      def execute_item(_exec_ctx, dispatch)
        [{ "json" => { "ran" => "pure", "target" => dispatch.config["target"] } }]
      end

      def simulate_item(_exec_ctx, dispatch)
        [{ "json" => { "ran" => "simulated", "target" => dispatch.config["target"] } }]
      end
    end
  end

  it "delegates to execute for an operation-less pure node" do
    node_class =
      Class.new(described_class) do
        description(name: "action:simulation_spec_pure", version: "1.0")
        simulation { pure }

        def execute(_exec_ctx)
          [[{ "json" => { "ran" => "execute" } }]]
        end
      end

    ctx, resolver, sandbox =
      build_context(node_class, parameters: {}, input_items: [{ "json" => {} }])
    expect(node_class.new.execute_simulation(ctx)).to eq([[{ "json" => { "ran" => "execute" } }]])
  ensure
    resolver&.dispose
    sandbox&.dispose
  end

  it "dispatches each item on its own resolved operation with a frozen config" do
    items = [
      { "json" => { "op" => "get", "t" => "a" } },
      { "json" => { "op" => "edit", "t" => "b" } },
    ]
    ctx, resolver, sandbox =
      build_context(
        operation_node,
        parameters: {
          "operation" => "={{ $json.op }}",
          "target" => "={{ $json.t }}",
        },
        input_items: items,
      )

    outputs = operation_node.new.execute_simulation(ctx)

    expect(outputs).to eq(
      [
        [
          { "json" => { "ran" => "pure", "target" => "a" } },
          { "json" => { "ran" => "simulated", "target" => "b" } },
        ],
      ],
    )
  ensure
    resolver&.dispose
    sandbox&.dispose
  end

  it "resolves the operation exactly once per item" do
    items = [{ "json" => { "op" => "get" } }, { "json" => { "op" => "edit" } }]
    ctx, resolver, sandbox =
      build_context(
        operation_node,
        parameters: {
          "operation" => "={{ $json.op }}",
        },
        input_items: items,
      )
    resolutions = Hash.new(0)
    original = ctx.method(:get_node_parameter)
    ctx.define_singleton_method(:get_node_parameter) do |path, item_index = 0, **kwargs|
      resolutions[[path, item_index]] += 1 if path == "operation"
      original.call(path, item_index, **kwargs)
    end

    operation_node.new.execute_simulation(ctx)

    expect(resolutions).to eq({ ["operation", 0] => 1, ["operation", 1] => 1 })
  ensure
    resolver&.dispose
    sandbox&.dispose
  end

  it "blocks the whole step at the first unclassified item" do
    items = [{ "json" => { "op" => "get" } }, { "json" => { "op" => "purge" } }]
    ctx, resolver, sandbox =
      build_context(
        operation_node,
        parameters: {
          "operation" => "={{ $json.op }}",
        },
        input_items: items,
      )

    expect { operation_node.new.execute_simulation(ctx) }.to raise_error(
      DiscourseWorkflows::Simulation::SafetyError,
    ) { |error| expect(error.params).to include(operation: "purge", step: "Step under test") }
  ensure
    resolver&.dispose
    sandbox&.dispose
  end

  it "blocks an operation that resolves to an unknown value" do
    ctx, resolver, sandbox =
      build_context(
        operation_node,
        parameters: {
          "operation" => "nonsense",
        },
        input_items: [{ "json" => {} }],
      )

    expect { operation_node.new.execute_simulation(ctx) }.to raise_error(
      DiscourseWorkflows::Simulation::SafetyError,
    ) { |error| expect(error.reason_key).to eq("unresolved_operation") }
  ensure
    resolver&.dispose
    sandbox&.dispose
  end

  it "blocks a node without a declaration" do
    node_class =
      Class.new(described_class) do
        description(name: "action:simulation_spec_undeclared", version: "1.0")

        def execute(_exec_ctx)
          [[]]
        end
      end
    ctx, resolver, sandbox =
      build_context(node_class, parameters: {}, input_items: [{ "json" => {} }])

    expect { node_class.new.execute_simulation(ctx) }.to raise_error(
      DiscourseWorkflows::Simulation::SafetyError,
    ) { |error| expect(error.reason_key).to eq("unsupported_step") }
  ensure
    resolver&.dispose
    sandbox&.dispose
  end

  describe "pure steps run read-only" do
    fab!(:user)

    def pure_node(&body)
      Class.new(described_class) do
        description(
          name: "action:simulation_spec_readonly",
          version: "1.0",
          properties: {
            operation: {
              type: :options,
              options: %w[get],
              default: "get",
            },
          },
        )
        simulation { pure "get" }

        define_method(:resolve_config) { |*_, **_| {} }
        define_method(:execute_item) { |_ctx, _dispatch| body.call }
      end
    end

    def run_pure(node_class)
      ctx, resolver, sandbox =
        build_context(node_class, parameters: {}, input_items: [{ "json" => {} }])
      node_class.new.execute_simulation(ctx)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "allows reads" do
      node_class = pure_node { [{ "json" => { "count" => User.count } }] }

      expect(run_pure(node_class).first.first["json"]["count"]).to eq(User.count)
    end

    it "blocks an ActiveRecord write" do
      node_class = pure_node { user.update_column(:updated_at, Time.zone.now) && [] }

      expect { run_pure(node_class) }.to raise_error(
        DiscourseWorkflows::Simulation::SafetyError,
      ) { |error| expect(error.reason_key).to eq("write_in_pure_step") }
    end

    it "blocks a write through the raw connection" do
      node_class = pure_node { DB.exec("UPDATE users SET updated_at = NOW() WHERE id = -1") && [] }

      expect { run_pure(node_class) }.to raise_error(
        DiscourseWorkflows::Simulation::SafetyError,
      ) { |error| expect(error.reason_key).to eq("write_in_pure_step") }
    end

    it "blocks a row lock" do
      node_class = pure_node { User.where(id: user.id).lock(true).to_a && [] }

      expect { run_pure(node_class) }.to raise_error(
        DiscourseWorkflows::Simulation::SafetyError,
      ) { |error| expect(error.reason_key).to eq("write_in_pure_step") }
    end
  end
end
