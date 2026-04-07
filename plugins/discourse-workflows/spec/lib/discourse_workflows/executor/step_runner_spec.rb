# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::StepRunner do
  def build_node(
    id: "1",
    type: "action:test",
    name: "test_node",
    configuration: {},
    condition: false
  )
    type_str = condition ? "condition:filter" : type
    DiscourseWorkflows::WorkflowSnapshot::SnapshotNode.new(
      id: id,
      type: type_str,
      type_version: "1.0",
      name: name,
      position: {
        "x" => 0,
        "y" => 0,
      },
      configuration: configuration,
    )
  end

  def build_state
    state = instance_double(DiscourseWorkflows::Executor::ExecutionState)
    allow(state).to receive(:next_step_position).and_return(0, 1, 2, 3)
    allow(state).to receive(:record_step)
    allow(state).to receive(:resolver_context).and_return({})
    allow(state).to receive(:user).and_return(nil)
    allow(state).to receive(:shared_sandbox).and_return(nil)
    state
  end

  def stub_node_type_class(outputs: [:main])
    klass =
      Class.new do
        extend DiscourseWorkflows::NodeTypeDescriptor

        attr_reader :configuration, :log

        def initialize(configuration: {})
          @configuration = configuration
          @log = DiscourseWorkflows::StepLog.new
        end
      end
    klass.define_singleton_method(:outputs) { outputs }
    klass
  end

  let(:state) { build_state }
  let(:runner) { described_class.new(state) }

  describe "#run" do
    it "returns a success outcome with finalized step" do
      node = build_node(configuration: { "key" => "value" })
      node_type_class = stub_node_type_class
      input_items = [{ "json" => { "x" => 1 } }]

      outcome =
        runner.run(node, input_items, node_type_class) do |instance|
          expect(instance).to be_a(node_type_class)
          [{ "json" => { "done" => true } }]
        end

      expect(outcome).to be_success
      expect(outcome.result).to eq([{ "json" => { "done" => true } }])
      expect(outcome.step).to be_success
      expect(outcome.step.output).to eq([{ "json" => { "done" => true } }])
      expect(outcome.step.finished_at).to be_present
    end

    it "returns an error outcome when block raises" do
      node = build_node(configuration: {})
      node_type_class = stub_node_type_class

      outcome = runner.run(node, [{ "json" => {} }], node_type_class) { raise "boom" }

      expect(outcome).to be_error
      expect(outcome.error.message).to eq("boom")
      expect(outcome.step).to be_error
      expect(outcome.step.error).to eq("boom")
      expect(outcome.step.finished_at).to be_present
    end

    it "returns an error outcome when step log has errors" do
      node = build_node(configuration: {})
      klass =
        Class.new do
          extend DiscourseWorkflows::NodeTypeDescriptor

          attr_reader :configuration, :expression_errors

          def self.outputs
            [:main]
          end

          def initialize(configuration: {})
            @configuration = configuration
            @expression_errors = []
          end

          def log
            log = DiscourseWorkflows::StepLog.new
            log.error("something went wrong")
            log
          end
        end

      outcome = runner.run(node, [{ "json" => {} }], klass) { [{ "json" => {} }] }

      expect(outcome).to be_error
      expect(outcome.error).to be_a(DiscourseWorkflows::StepLogError)
      expect(outcome.error.message).to match(/something went wrong/)
    end

    it "returns a wait outcome for WaitForResume" do
      node = build_node(configuration: {})
      node_type_class = stub_node_type_class
      wait_error = DiscourseWorkflows::WaitForWebhook.new

      outcome = runner.run(node, [{ "json" => {} }], node_type_class) { raise wait_error }

      expect(outcome).to be_wait
      expect(outcome.error).to eq(wait_error)
      expect(outcome.step.node_id).to eq("1")
    end

    it "passes raw config to all node types" do
      action_node =
        build_node(type: "action:test", configuration: { "url" => "={{ trigger.url }}" })
      core_node = build_node(type: "core:test", configuration: { "url" => "={{ trigger.url }}" })
      node_type_class = stub_node_type_class

      action_config = nil
      runner.run(action_node, [{ "json" => {} }], node_type_class) do |instance, _resolver|
        action_config = instance.configuration
        []
      end

      core_config = nil
      runner.run(core_node, [{ "json" => {} }], node_type_class) do |instance, _resolver|
        core_config = instance.configuration
        []
      end

      expect(action_config).to eq({ "url" => "={{ trigger.url }}" })
      expect(core_config).to eq({ "url" => "={{ trigger.url }}" })
    end

    it "sets filtered status for branching nodes with empty primary output" do
      node = build_node(type: "condition:test", configuration: {})
      outputs = [{ key: "true", label_key: "t" }, { key: "false", label_key: "f" }]
      node_type_class = stub_node_type_class(outputs: outputs)

      outcome = runner.run(node, [{ "json" => {} }], node_type_class) { [[], [{ "json" => {} }]] }

      expect(outcome).to be_success
      expect(outcome.step).to be_filtered
    end

    it "sets success status for branching nodes with primary output" do
      node = build_node(type: "condition:test", configuration: {})
      outputs = [{ key: "true", label_key: "t" }, { key: "false", label_key: "f" }]
      node_type_class = stub_node_type_class(outputs: outputs)

      outcome = runner.run(node, [{ "json" => {} }], node_type_class) { [[{ "json" => {} }], []] }

      expect(outcome).to be_success
      expect(outcome.step).to be_success
    end

    it "redacts sensitive headers in step metadata" do
      node =
        build_node(
          configuration: {
            "headers" => [
              { "key" => "Authorization", "value" => "Bearer secret123" },
              { "key" => "Content-Type", "value" => "application/json" },
            ],
          },
        )
      node_type_class = stub_node_type_class

      outcome = runner.run(node, [{ "json" => {} }], node_type_class) { [] }

      resolved = outcome.step.metadata&.dig("resolved_configuration")
      auth_header = resolved["headers"].find { |h| h["key"] == "Authorization" }
      content_header = resolved["headers"].find { |h| h["key"] == "Content-Type" }

      expect(auth_header["value"]).to eq("[FILTERED]")
      expect(content_header["value"]).to eq("application/json")
    end

    it "builds conditions metadata with raw expressions" do
      node =
        build_node(
          type: "condition:test",
          configuration: {
            "conditions" => [{ "leftValue" => "={{ x }}", "rightValue" => "1" }],
          },
        )
      klass =
        Class.new do
          extend DiscourseWorkflows::NodeTypeDescriptor

          attr_reader :configuration

          def self.outputs
            [{ key: "true", label_key: "t" }, { key: "false", label_key: "f" }]
          end

          def initialize(configuration: {})
            @configuration = configuration
          end

          def log
            DiscourseWorkflows::StepLog.new
          end
        end

      outcome =
        runner.run(node, [{ "json" => {} }], klass) do |inst, resolver|
          exec_ctx =
            DiscourseWorkflows::NodeExecutionContext.new(
              input_items: [{ "json" => {} }],
              resolver: resolver,
            )
          exec_ctx.instance_variable_get(:@condition_details).concat(
            [
              {
                "operator" => "equals",
                "leftValue" => "42",
                "rightValue" => "1",
                "result" => false,
              },
            ],
          )
          exec_ctx.instance_variable_set(
            :@resolved_config,
            { "conditions" => [{ "leftValue" => "={{ x }}", "rightValue" => "1" }] },
          )
          [[[], [{ "json" => {} }]], exec_ctx]
        end

      conditions = outcome.step.metadata&.dig("conditions")
      expect(conditions.first["leftExpression"]).to eq("={{ x }}")
      expect(conditions.first["rightExpression"]).to eq("1")
      expect(conditions.first["operator"]).to eq("equals")
    end

    it "returns error outcome when expression errors are present" do
      node = build_node(configuration: {})
      node_type_class = stub_node_type_class

      outcome =
        runner.run(node, [{ "json" => {} }], node_type_class) do |inst, resolver|
          exec_ctx =
            DiscourseWorkflows::NodeExecutionContext.new(
              input_items: [{ "json" => {} }],
              resolver: resolver,
            )
          exec_ctx.instance_variable_get(:@expression_errors).concat(
            [{ expression: "={{ bad }}", error: "undefined variable" }],
          )
          [[], exec_ctx]
        end

      expect(outcome).to be_error
      expect(outcome.error).to be_a(DiscourseWorkflows::StepLogError)
      expect(outcome.error.message).to match(/={{ bad }}: undefined variable/)
    end
  end

  describe "resolved configuration metadata" do
    it "uses resolved_config from exec_ctx when available" do
      resolved = { "url" => "https://example.com" }
      node_type_class = stub_node_type_class
      node = build_node

      outcome =
        runner.run(node, [{ "json" => {} }], node_type_class) do |inst, resolver|
          exec_ctx =
            DiscourseWorkflows::NodeExecutionContext.new(
              input_items: [{ "json" => {} }],
              resolver: resolver,
            )
          exec_ctx.instance_variable_set(:@resolved_config, resolved)
          [[{ "json" => {} }], exec_ctx]
        end

      expect(outcome.step.metadata["resolved_configuration"]).to eq(resolved)
    end

    it "falls back to resolver when exec_ctx has no resolved_config" do
      node_type_class = stub_node_type_class
      node = build_node

      outcome =
        runner.run(node, [{ "json" => {} }], node_type_class) { |inst, res| [{ "json" => {} }] }

      expect(outcome.step.metadata).to have_key("resolved_configuration")
    end
  end

  describe "condition metadata" do
    it "does not attach conditions for non-condition nodes" do
      node_type_class = stub_node_type_class
      node = build_node(condition: false)

      outcome =
        runner.run(node, [{ "json" => {} }], node_type_class) { |inst, res| [{ "json" => {} }] }

      expect(outcome.step.metadata).not_to have_key("conditions")
    end
  end

  describe "step log handling" do
    it "does not attach empty logs" do
      node_type_class = stub_node_type_class
      node = build_node

      outcome =
        runner.run(node, [{ "json" => {} }], node_type_class) { |inst, res| [{ "json" => {} }] }

      expect(outcome.step.metadata).not_to have_key("logs")
    end
  end
end
