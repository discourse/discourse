# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)
  fab!(:topic)
  fab!(:tag)
  fab!(:false_tag) { Fabricate(:tag, name: "needs-review") }

  before { SiteSetting.tagging_enabled = true }

  def build_workflow
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:topic_closed", name: "Topic Closed"
        g.node "action-1",
               "action:topic_tags",
               name: "Topic Tags",
               configuration: {
                 "topic_id" => "={{ $trigger.topic_id }}",
                 "tag_names" => tag.name,
               }
        g.chain "trigger-1", "action-1"
      end
    Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
  end

  describe "#run" do
    context "with a simple trigger -> action workflow" do
      fab!(:workflow) { build_workflow }
      let(:trigger_data) { { topic_id: topic.id, tags: topic.tags.pluck(:name) } }

      it "executes successfully and tags the topic" do
        execution = described_class.new(workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
        expect(topic.reload.tags).to include(tag)
      end

      it "creates an execution record" do
        expect { described_class.new(workflow, "trigger-1", trigger_data).run }.to change {
          DiscourseWorkflows::Execution.count
        }.by(1)
      end

      it "uses an existing execution record when provided" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:manual"
            g.node "log-1", "action:log"
            g.chain "trigger-1", "log-1"
          end
        workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)
        snapshot = DiscourseWorkflows::WorkflowSnapshot.from_workflow(workflow, published: false)
        existing_execution =
          Fabricate(
            :discourse_workflows_execution,
            workflow: workflow,
            status: :running,
            execution_mode: :manual,
            trigger_node_id: "trigger-1",
          )
        Fabricate(
          :discourse_workflows_execution_data,
          execution: existing_execution,
          workflow_data: snapshot.to_h,
        )
        options =
          described_class::ExecutionOptions.new(
            execution_mode: :manual,
            workflow_snapshot: snapshot,
            existing_execution: existing_execution,
          )

        expect { described_class.new(workflow, "trigger-1", {}, options).run }.not_to change {
          DiscourseWorkflows::Execution.count
        }

        expect(existing_execution.reload.status).to eq("success")
        expect(
          existing_execution.execution_data.steps_array.map { |step| step["node_id"] },
        ).to include("log-1")
      end

      it "stores context with item arrays in the execution" do
        execution = described_class.new(workflow, "trigger-1", trigger_data).run

        ed = execution.execution_data.context_data
        expect(ed["Topic Closed"]).to be_an(Array)

        topic_tags_output = ed["Topic Tags"]
        expect(topic_tags_output).to be_an(Array)
        expect(topic_tags_output.first["json"]["tag_names"]).to eq([tag.name])
      end

      it "handles errors gracefully" do
        execution = described_class.new(workflow, "trigger-1", { topic_id: -999, tags: [] }).run

        expect(execution).to have_attributes(status: "error", error: be_present)
      end

      it "skips unpublished workflows" do
        unpublish_workflow!(workflow)

        execution = described_class.new(workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("skipped")
      end

      it "updates an existing execution when skipped before start" do
        unpublish_workflow!(workflow)
        existing_execution =
          Fabricate(
            :discourse_workflows_execution,
            workflow: workflow,
            status: :running,
            trigger_node_id: "trigger-1",
          )
        options = described_class::ExecutionOptions.new(existing_execution: existing_execution)

        expect {
          described_class.new(workflow, "trigger-1", trigger_data, options).run
        }.not_to change { DiscourseWorkflows::Execution.count }

        expect(existing_execution.reload.status).to eq("skipped")
      end

      it "preloads dependencies from the active workflow snapshot" do
        executor = described_class.new(workflow, "trigger-1", trigger_data)
        snapshot =
          DiscourseWorkflows::WorkflowSnapshot.new(
            "nodes" => [
              {
                "id" => "http-1",
                "type" => "action:http_request",
                "parameters" => {
                  "authentication" => "basic_auth",
                },
                "credentials" => {
                  "auth" => {
                    "id" => "123",
                    "credential_type" => "basic_auth",
                  },
                },
              },
            ],
            "connections" => [],
          )
        executor.instance_variable_set(:@snapshot, snapshot)

        expect(executor.send(:preloaded_workflow_dependencies)["http-1"]).to include(
          "credential_id:123",
        )
      end
    end

    it "fails when trigger node is not in the snapshot" do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      executor = described_class.new(workflow, "trigger-1", {})
      workflow.active_version.update!(nodes: [])

      execution = executor.run

      expect(execution).to have_attributes(
        status: "error",
        error: include("not found in workflow snapshot"),
      )
    end

    it "follows the correct branch of a condition node" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "condition-1",
                 "condition:if",
                 configuration: {
                   "conditions" => [
                     {
                       "id" => "1",
                       "leftValue" => "={{ $json.tags }}",
                       "rightValue" => "bug",
                       "operator" => {
                         "type" => "array",
                         "operation" => "contains",
                       },
                     },
                   ],
                   "combinator" => "and",
                 }
          g.node "action-true",
                 "action:topic_tags",
                 configuration: {
                   "topic_id" => "={{ $trigger.topic_id }}",
                   "tag_names" => tag.name,
                 }
          g.node "action-false",
                 "action:topic_tags",
                 configuration: {
                   "topic_id" => "={{ $trigger.topic_id }}",
                   "tag_names" => false_tag.name,
                 }
          g.chain "trigger-1", "condition-1"
          g.connect "condition-1", "action-true", output: "true"
          g.connect "condition-1", "action-false", output: "false"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { topic_id: topic.id, tags: %w[bug help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags.map(&:name)).to include(tag.name)
      expect(topic.reload.tags.map(&:name)).not_to include("needs-review")

      condition_step = execution.execution_data.find_step(node_id: "condition-1")
      expect(condition_step["metadata"]["conditions"]).to be_present
      expect(condition_step["metadata"]["conditions"].first).to include(
        "left" => include("bug"),
        "operator" => "contains",
        "passed" => true,
      )
    end

    context "with a filter workflow" do
      let(:filter_workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_closed"
            g.node "filter-1",
                   "condition:filter",
                   configuration: {
                     "conditions" => [
                       {
                         "id" => "1",
                         "leftValue" => "={{ $json.tags }}",
                         "rightValue" => "bug",
                         "operator" => {
                           "type" => "array",
                           "operation" => "contains",
                         },
                       },
                     ],
                     "combinator" => "and",
                   }
            g.node "action-1",
                   "action:topic_tags",
                   configuration: {
                     "topic_id" => "={{ $trigger.topic_id }}",
                     "tag_names" => tag.name,
                   }
            g.chain "trigger-1", "filter-1"
            g.connect "filter-1", "action-1", output: "true"
          end
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
      end

      it "continues execution when filter passes" do
        trigger_data = { topic_id: topic.id, tags: %w[bug help] }
        execution = described_class.new(filter_workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
        expect(topic.reload.tags.map(&:name)).to include(tag.name)
      end

      it "stops execution when filter does not pass" do
        trigger_data = { topic_id: topic.id, tags: %w[feature help] }
        execution = described_class.new(filter_workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
        expect(topic.reload.tags.map(&:name)).not_to include(tag.name)
      end
    end

    it "marks condition step as filtered when all items fail" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "filter-1",
                 "condition:filter",
                 configuration: {
                   "conditions" => [
                     {
                       "id" => "1",
                       "leftValue" => "={{ $json.tags }}",
                       "rightValue" => "bug",
                       "operator" => {
                         "type" => "array",
                         "operation" => "contains",
                       },
                     },
                   ],
                   "combinator" => "and",
                 }
          g.chain "trigger-1", "filter-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { topic_id: topic.id, tags: %w[feature help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      filter_step = execution.execution_data.find_step(node_id: "filter-1")
      expect(filter_step["status"]).to eq("filtered")
    end

    it "routes rejected filter items to the false branch" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "filter-1",
                 "condition:filter",
                 configuration: {
                   "conditions" => [
                     {
                       "id" => "1",
                       "leftValue" => "={{ $json.tags }}",
                       "rightValue" => "bug",
                       "operator" => {
                         "type" => "array",
                         "operation" => "contains",
                       },
                     },
                   ],
                   "combinator" => "and",
                 }
          g.node "action-false",
                 "action:set_fields",
                 name: "Rejected",
                 configuration: {
                   "include_other_fields" => true,
                   "mode" => "manual",
                   "assignments" => {
                     "assignments" => [
                       { "name" => "rejected", "value" => "yes", "type" => "string" },
                     ],
                   },
                 }
          g.chain "trigger-1", "filter-1"
          g.connect "filter-1", "action-false", output: "false"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { topic_id: topic.id, tags: %w[feature help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      expect(execution.execution_data.find_step(node_id: "action-false")).to be_present
      expect(execution.execution_data.context_data["Rejected"].first.dig("json", "rejected")).to eq(
        "yes",
      )
    end

    it "records an error step for unknown node types" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "unknown-1", "action:nonexistent_type"
          g.chain "trigger-1", "unknown-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")

      step = execution.execution_data.find_step(node_id: "unknown-1")
      expect(step["status"]).to eq("error")
      expect(step["error"]).to include("Unknown node type 'action:nonexistent_type'")
    end

    it "persists node logs to step metadata" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "log-1",
                 "action:log",
                 configuration: {
                   "entries" => {
                     "values" => [{ "key" => "topic", "value" => "={{ $json.topic_id }}" }],
                   },
                 }
          g.chain "trigger-1", "log-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      log_step = execution.execution_data.find_step(node_id: "log-1")
      logs = log_step.dig("metadata", "logs")
      expect(logs).to be_present
      expect(logs.first).to include("key" => "topic", "value" => topic.id.to_s)
    end

    it "routes downstream with log input items" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "log-1",
                 "action:log",
                 configuration: {
                   "entries" => {
                     "values" => [{ "key" => "topic", "value" => "={{ $json.topic_id }}" }],
                   },
                 }
          g.node "set-fields-1",
                 "action:set_fields",
                 configuration: {
                   "assignments" => {
                     "assignments" => [
                       { "name" => "logged", "value" => "true", "type" => "boolean" },
                     ],
                   },
                 }
          g.chain "trigger-1", "log-1", "set-fields-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")

      expected_item = { "json" => trigger_data.stringify_keys, "pairedItem" => { "item" => 0 } }
      log_step = execution.execution_data.find_step(node_id: "log-1")
      expect(log_step["output"]).to eq([expected_item])
      expect(log_step.dig("metadata", "logs").first).to include(
        "key" => "topic",
        "value" => topic.id.to_s,
      )

      set_fields_step = execution.execution_data.find_step(node_id: "set-fields-1")
      expect(set_fields_step["output"]).to eq(
        [expected_item.deep_merge("json" => { "logged" => true })],
      )

      run_data = execution.execution_data.run_data
      expect(run_data.dig("Log-1", 0, "outputs", 0, "item_count")).to eq(1)
      expect(run_data.dig("Log-1", 0, "outputs", 0, "items")).to eq([expected_item])
      expect(run_data.dig(set_fields_step["node_name"], 0, "inputs", 0, "item_count")).to eq(1)
    end

    it "fails the step when expression errors are logged" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "code-1",
                 "action:code",
                 configuration: {
                   "code" => "throw new Error('deliberate failure');",
                 }
          g.chain "trigger-1", "code-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("error")
      code_step = execution.execution_data.find_step(node_id: "code-1")
      expect(code_step["status"]).to eq("error")
    end

    it "continues through the regular output when onError asks to continue" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "code-1",
                 "action:code",
                 configuration: {
                   "code" => "throw new Error('deliberate failure');",
                   "onError" => "continueRegularOutput",
                 }
          g.node "code-2", "action:code", configuration: { "code" => "return $input.all();" }
          g.chain "trigger-1", "code-1", "code-2"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      code_1_step = execution.execution_data.find_step(node_id: "code-1")
      expect(code_1_step["status"]).to eq("success")
      expect(code_1_step.dig("metadata", "handled_error", "message")).to include(
        "deliberate failure",
      )

      code_2_step = execution.execution_data.find_step(node_id: "code-2")
      expect(code_2_step["input"].first["json"]).to include("topic_id" => topic.id)
    end

    it "routes error items through the error output when onError asks for an error branch" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "code-1",
                 "action:code",
                 configuration: {
                   "code" => "throw new Error('deliberate failure');",
                   "onError" => "continueErrorOutput",
                 }
          g.node "code-2", "action:code", configuration: { "code" => "return $input.all();" }
          g.connect "trigger-1", "code-1"
          g.connect "code-1", "code-2", output: 1
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      code_2_step = execution.execution_data.find_step(node_id: "code-2")
      expect(code_2_step["input"].first["json"]).to include("topic_id" => topic.id)
      expect(code_2_step["input"].first.dig("error", "message")).to include("deliberate failure")
      expect(code_2_step["input"].first["pairedItem"]).to eq("item" => 0)
    end

    it "truncates long error messages" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "code-1",
                 "action:code",
                 configuration: {
                   "code" => "throw new Error('x'.repeat(2000));",
                 }
          g.chain "trigger-1", "code-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("error")
      expect(execution.error.length).to be <= 1000
    end

    context "with alwaysOutputData" do
      def chained_code_graph(always_output_data:)
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "code-1",
                 "action:code",
                 configuration: {
                   "code" => "return [];",
                   "alwaysOutputData" => always_output_data,
                 }
          g.node "code-2", "action:code", configuration: { "code" => "return $input.all();" }
          g.chain "trigger-1", "code-1", "code-2"
        end
      end

      let(:trigger_data) { { topic_id: topic.id, tags: [] } }

      it "skips downstream when the first code returns no items" do
        workflow =
          Fabricate(
            :discourse_workflows_workflow,
            created_by: user,
            published: true,
            **chained_code_graph(always_output_data: false),
          )

        execution = described_class.new(workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
        expect(execution.execution_data.find_step(node_id: "code-1")["status"]).to eq("success")
        expect(execution.execution_data.find_step(node_id: "code-2")).to be_nil
      end

      it "feeds downstream an empty item when alwaysOutputData is set" do
        workflow =
          Fabricate(
            :discourse_workflows_workflow,
            created_by: user,
            published: true,
            **chained_code_graph(always_output_data: true),
          )

        execution = described_class.new(workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
        code_2_step = execution.execution_data.find_step(node_id: "code-2")
        expect(code_2_step["status"]).to eq("success")
        expect(code_2_step["input"]).to eq(
          [{ "json" => {}, "pairedItem" => [{ "item" => 0, "input" => 0 }] }],
        )
        expect(code_2_step["output"]).to eq(
          [{ "json" => {}, "pairedItem" => [{ "item" => 0, "input" => 0 }] }],
        )
      end
    end

    context "with rate limiting" do
      before { RateLimiter.enable }
      after { RateLimiter.disable }

      it "creates a rate_limited execution when limits are exceeded" do
        SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1

        graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

        trigger_data = { topic_id: topic.id, tags: [] }

        first_execution = described_class.new(workflow, "trigger-1", trigger_data).run
        expect(first_execution.status).to eq("success")

        second_execution = described_class.new(workflow, "trigger-1", trigger_data).run
        expect(second_execution.status).to eq("rate_limited")
        expect(second_execution.trigger_data).to eq("rate_limited" => true)
      end

      it "updates an existing execution when limits are exceeded" do
        SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1

        graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
        trigger_data = { topic_id: topic.id, tags: [] }
        expect(described_class.new(workflow, "trigger-1", trigger_data).run.status).to eq("success")

        existing_execution =
          Fabricate(
            :discourse_workflows_execution,
            workflow: workflow,
            status: :running,
            trigger_node_id: "trigger-1",
          )
        options = described_class::ExecutionOptions.new(existing_execution: existing_execution)

        expect {
          described_class.new(workflow, "trigger-1", trigger_data, options).run
        }.not_to change { DiscourseWorkflows::Execution.count }

        existing_execution.reload
        expect(existing_execution.status).to eq("rate_limited")
        expect(existing_execution.trigger_data).to eq("rate_limited" => true)
      end
    end

    context "with an unavailable node" do
      let(:unavailable_reason_key) do
        "discourse_workflows.unavailable_reasons.test_plugin_disabled"
      end

      let(:unavailable_node_class) do
        reason_key = unavailable_reason_key

        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "action:unavailable_test",
            available: false,
            unavailable_reason_key: -> { reason_key },
          )

          def execute(_ctx)
            raise "should never be called"
          end
        end
      end

      let(:plugin) do
        p = Plugin::Instance.new
        p.enabled_site_setting(:discourse_workflows_enabled)
        p
      end

      before do
        DiscoursePluginRegistry.register_discourse_workflows_node(unavailable_node_class, plugin)
        DiscourseWorkflows::Registry.reset_indexes!
      end

      after { unregister_workflow_nodes(unavailable_node_class) }

      it "passes data through and records a skipped step" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_closed", name: "Topic Closed"
            g.node "unavailable-1", "action:unavailable_test", name: "Unavailable Node"
            g.node "action-1",
                   "action:topic_tags",
                   name: "Topic Tags",
                   configuration: {
                     "topic_id" => "={{ $trigger.topic_id }}",
                     "tag_names" => tag.name,
                   }
            g.chain "trigger-1", "unavailable-1", "action-1"
          end
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

        trigger_data = { topic_id: topic.id, tags: topic.tags.pluck(:name) }
        execution = described_class.new(workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
        expect(topic.reload.tags).to include(tag)

        step = execution.execution_data.find_step(node_id: "unavailable-1")
        expect(step["status"]).to eq("skipped")
        expect(step["error"]).to eq(unavailable_reason_key)
      end

      it "does not execute the unavailable node" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_closed", name: "Topic Closed"
            g.node "unavailable-1", "action:unavailable_test", name: "Unavailable Node"
            g.chain "trigger-1", "unavailable-1"
          end
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

        trigger_data = { topic_id: topic.id, tags: [] }
        execution = described_class.new(workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
      end
    end

    context "with versioned node implementations" do
      let(:v1_node_class) do
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:executor_versioned_test", version: "1.0")

          def execute(_ctx)
            [[DiscourseWorkflows::Item.wrap("version" => "1.0")]]
          end
        end
      end

      let(:v2_node_class) do
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:executor_versioned_test", version: "2.0")

          def execute(_ctx)
            [[DiscourseWorkflows::Item.wrap("version" => "2.0")]]
          end
        end
      end

      before do
        plugin = Plugin::Instance.new
        DiscoursePluginRegistry.register_discourse_workflows_node(v1_node_class, plugin)
        DiscoursePluginRegistry.register_discourse_workflows_node(v2_node_class, plugin)
        DiscourseWorkflows::Registry.reset_indexes!
      end

      after { unregister_workflow_nodes(v1_node_class, v2_node_class) }

      it "dispatches execution to the saved node type version" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_closed", name: "Topic Closed"
            g.node "action-1", "action:executor_versioned_test", name: "Versioned"
            g.chain "trigger-1", "action-1"
          end
        graph[:nodes].find { |node| node["id"] == "action-1" }["typeVersion"] = "2.0"
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution.status).to eq("success")
        expect(execution.execution_data.entries.dig("action-1", 0, "output", 0, "json")).to eq(
          "version" => "2.0",
        )
      end
    end

    context "with node result contracts" do
      let(:raw_array_node_class) do
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:raw_result_test", version: "1.0")

          def execute(exec_ctx)
            [exec_ctx.input_items]
          end
        end
      end

      let(:named_outputs_node_class) do
        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "action:named_outputs_test",
            version: "1.0",
            outputs: [{ key: "true", label_key: "true" }, { key: "false", label_key: "false" }],
          )

          def execute(exec_ctx)
            { "true" => exec_ctx.input_items, "false" => [] }
          end
        end
      end

      let(:malformed_array_node_class) do
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:malformed_array_test", version: "1.0")

          def execute(exec_ctx)
            [exec_ctx.input_items.first]
          end
        end
      end

      let(:oversized_output_node_class) do
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:oversized_output_test", version: "1.0")

          def execute(_exec_ctx)
            [[{ "json" => { "body" => "x" * 200 } }, { "json" => { "body" => "small" } }]]
          end
        end
      end

      before do
        plugin = Plugin::Instance.new
        DiscoursePluginRegistry.register_discourse_workflows_node(raw_array_node_class, plugin)
        DiscoursePluginRegistry.register_discourse_workflows_node(named_outputs_node_class, plugin)
        DiscoursePluginRegistry.register_discourse_workflows_node(
          malformed_array_node_class,
          plugin,
        )
        DiscoursePluginRegistry.register_discourse_workflows_node(
          oversized_output_node_class,
          plugin,
        )
        DiscourseWorkflows::Registry.reset_indexes!
      end

      after do
        unregister_workflow_nodes(
          raw_array_node_class,
          named_outputs_node_class,
          malformed_array_node_class,
          oversized_output_node_class,
        )
      end

      it "accepts positional output arrays" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_closed"
            g.node "raw-1", "action:raw_result_test", name: "Raw Result"
            g.chain "trigger-1", "raw-1"
          end
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

        execution = described_class.new(workflow, "trigger-1", { topic_id: topic.id }).run

        expect(execution.status).to eq("success")
        expect(
          execution.execution_data.context_data["Raw Result"].first.dig("json", "topic_id"),
        ).to eq(topic.id)
      end

      it "rejects named output hashes" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_closed"
            g.node "named-1", "action:named_outputs_test"
            g.chain "trigger-1", "named-1"
          end
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

        execution = described_class.new(workflow, "trigger-1", { topic_id: topic.id }).run

        expect(execution.status).to eq("error")
        expect(execution.error).to include("execute must return Array<Array<Item>>, got Hash")
      end

      it "reports contract errors for malformed positional output arrays" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_closed"
            g.node "malformed-1", "action:malformed_array_test"
            g.chain "trigger-1", "malformed-1"
          end
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

        execution = described_class.new(workflow, "trigger-1", { topic_id: topic.id }).run

        expect(execution.status).to eq("error")
        expect(execution.error).to include("execute must return Array<Array<Item>>")
      end

      it "truncates oversized node outputs before routing downstream" do
        stub_const(described_class, :MAX_NODE_OUTPUT_BYTES, 100) do
          graph =
            build_workflow_graph do |g|
              g.node "trigger-1", "trigger:topic_closed"
              g.node "oversized-1", "action:oversized_output_test", name: "Oversized"
              g.node "code-1", "action:code", configuration: { "code" => "return $input.all();" }
              g.chain "trigger-1", "oversized-1", "code-1"
            end
          workflow =
            Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

          execution = described_class.new(workflow, "trigger-1", { topic_id: topic.id }).run

          expect(execution.status).to eq("success")

          oversized_step = execution.execution_data.find_step(node_id: "oversized-1")
          expect(oversized_step["output"]).to eq([])
          expect(oversized_step.dig("metadata", "logs").first["message"]).to include(
            "Node output truncated",
          )
          expect(execution.execution_data.find_step(node_id: "code-1")).to be_nil
        end
      end
    end
  end
end
