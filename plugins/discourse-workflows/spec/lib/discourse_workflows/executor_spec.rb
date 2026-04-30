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
                 "topic_id" => "={{ trigger.topic_id }}",
                 "tag_names" => tag.name,
               }
        g.chain "trigger-1", "action-1"
      end
    Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)
  end

  describe "#run" do
    context "with a simple trigger -> action workflow" do
      let(:workflow) { build_workflow }
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

      it "skips disabled workflows" do
        workflow.update!(enabled: false)

        execution = described_class.new(workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("skipped")
      end
    end

    it "fails when trigger node is not in the snapshot" do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      executor = described_class.new(workflow, "trigger-1", {})
      workflow.update!(nodes: [])

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
                   "topic_id" => "={{ trigger.topic_id }}",
                   "tag_names" => tag.name,
                 }
          g.node "action-false",
                 "action:topic_tags",
                 configuration: {
                   "topic_id" => "={{ trigger.topic_id }}",
                   "tag_names" => false_tag.name,
                 }
          g.chain "trigger-1", "condition-1"
          g.connect "condition-1", "action-true", output: "true"
          g.connect "condition-1", "action-false", output: "false"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      trigger_data = { topic_id: topic.id, tags: %w[bug help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags.map(&:name)).to include(tag.name)
      expect(topic.reload.tags.map(&:name)).not_to include("needs-review")
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
                     "topic_id" => "={{ trigger.topic_id }}",
                     "tag_names" => tag.name,
                   }
            g.chain "trigger-1", "filter-1"
            g.connect "filter-1", "action-1", output: "true"
          end
        Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)
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
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

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
                   "include_input" => true,
                   "mode" => "manual",
                   "fields" => [{ "key" => "rejected", "value" => "yes", "type" => "string" }],
                 }
          g.chain "trigger-1", "filter-1"
          g.connect "filter-1", "action-false", output: "false"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

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
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

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
                   "entries" => [{ "key" => "topic", "value" => "={{ $json.topic_id }}" }],
                 }
          g.chain "trigger-1", "log-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      log_step = execution.execution_data.find_step(node_id: "log-1")
      logs = log_step.dig("metadata", "logs")
      expect(logs).to be_present
      expect(logs.first).to include("key" => "topic", "value" => topic.id.to_s)
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
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("error")
      code_step = execution.execution_data.find_step(node_id: "code-1")
      expect(code_step["status"]).to eq("error")
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
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("error")
      expect(execution.error.length).to be <= 1000
    end

    context "with rate limiting" do
      before { RateLimiter.enable }
      after { RateLimiter.disable }

      it "creates a rate_limited execution when limits are exceeded" do
        SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1

        graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

        trigger_data = { topic_id: topic.id, tags: [] }

        first_execution = described_class.new(workflow, "trigger-1", trigger_data).run
        expect(first_execution.status).to eq("success")

        second_execution = described_class.new(workflow, "trigger-1", trigger_data).run
        expect(second_execution.status).to eq("rate_limited")
        expect(second_execution.trigger_data).to eq("rate_limited" => true)
      end
    end

    it "raises when run_as_username references a non-existent user" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "action-1",
                 "action:topic_tags",
                 configuration: {
                   "topic_id" => "={{ trigger.topic_id }}",
                   "tag_names" => tag.name,
                 }
          g.chain "trigger-1", "action-1"
        end
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          run_as_username: "nonexistent_user",
          **graph,
        )

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("error")
      expect(execution.error).to include(
        "Couldn't run this workflow as user: nonexistent_user. User not found.",
      )
    end

    context "with an unavailable node" do
      let(:unavailable_node_class) do
        Class.new(DiscourseWorkflows::NodeType) do
          def self.identifier
            "action:unavailable_test"
          end

          def self.name
            "DiscourseWorkflows::NodeTypes::UnavailableTest"
          end

          def self.available?
            false
          end

          def self.unavailable_reason_key
            "discourse_workflows.unavailable_reasons.test_plugin_disabled"
          end

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

      after do
        DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |h|
          h[:value] == unavailable_node_class
        end
        DiscourseWorkflows::Registry.reset_indexes!
      end

      it "passes data through and records a skipped step" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_closed", name: "Topic Closed"
            g.node "unavailable-1", "action:unavailable_test", name: "Unavailable Node"
            g.node "action-1",
                   "action:topic_tags",
                   name: "Topic Tags",
                   configuration: {
                     "topic_id" => "={{ trigger.topic_id }}",
                     "tag_names" => tag.name,
                   }
            g.chain "trigger-1", "unavailable-1", "action-1"
          end
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

        trigger_data = { topic_id: topic.id, tags: topic.tags.pluck(:name) }
        execution = described_class.new(workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
        expect(topic.reload.tags).to include(tag)

        step = execution.execution_data.find_step(node_id: "unavailable-1")
        expect(step["status"]).to eq("skipped")
      end

      it "does not execute the unavailable node" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_closed", name: "Topic Closed"
            g.node "unavailable-1", "action:unavailable_test", name: "Unavailable Node"
            g.chain "trigger-1", "unavailable-1"
          end
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

        trigger_data = { topic_id: topic.id, tags: [] }
        execution = described_class.new(workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
      end
    end
  end
end
