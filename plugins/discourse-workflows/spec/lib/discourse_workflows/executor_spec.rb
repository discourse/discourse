# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)
  fab!(:topic)
  fab!(:tag)
  fab!(:false_tag) { Fabricate(:tag, name: "needs-review") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
  end

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

      it "supports $json expressions in filter conditions" do
        trigger_data = { topic_id: topic.id, tags: %w[bug help] }
        execution = described_class.new(filter_workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
        expect(topic.reload.tags.map(&:name)).to include(tag.name)

        filter_step = execution.execution_data.find_step(node_id: "filter-1")
        expect(filter_step["metadata"].dig("conditions", 0, "left")).to eq(%w[bug help])
      end

      it "stops execution when filter does not pass" do
        trigger_data = { topic_id: topic.id, tags: %w[feature help] }
        execution = described_class.new(filter_workflow, "trigger-1", trigger_data).run

        expect(execution.status).to eq("success")
        expect(topic.reload.tags.map(&:name)).not_to include(tag.name)
      end
    end

    it "stores resolved configuration and result on execution steps" do
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
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      trigger_data = { topic_id: topic.id, tags: %w[bug help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      filter_step = execution.execution_data.find_step(node_id: "filter-1")
      expect(filter_step).to include("status" => "success")
      expect(filter_step["metadata"]).to include(
        "resolved_configuration" => be_present,
        "conditions" => be_present,
      )
      expect(filter_step["metadata"]["conditions"].first["passed"]).to be(true)
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

    it "redacts sensitive headers in step metadata" do
      stub_request(:get, "https://api.example.com/test").to_return(
        status: 200,
        body: '{"ok": true}',
        headers: {
          "Content-Type" => "application/json",
        },
      )

      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "http-1",
                 "action:http_request",
                 configuration: {
                   "method" => "GET",
                   "url" => "https://api.example.com/test",
                   "authentication" => "none",
                   "headers" => [
                     { "key" => "Authorization", "value" => "Bearer secret123" },
                     { "key" => "Content-Type", "value" => "application/json" },
                     { "key" => "X-Api-Key", "value" => "my-secret-key" },
                   ],
                 }
          g.chain "trigger-1", "http-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      trigger_data = { topic_id: topic.id, tags: [] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      step = execution.execution_data.find_step(node_id: "http-1")
      resolved_headers = step.dig("metadata", "resolved_configuration", "headers")

      auth_header = resolved_headers.find { |h| h["key"] == "Authorization" }
      content_header = resolved_headers.find { |h| h["key"] == "Content-Type" }
      api_key_header = resolved_headers.find { |h| h["key"] == "X-Api-Key" }

      expect(auth_header["value"]).to eq("[FILTERED]")
      expect(api_key_header["value"]).to eq("[FILTERED]")
      expect(content_header["value"]).to eq("application/json")
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
      end
    end
  end
end
