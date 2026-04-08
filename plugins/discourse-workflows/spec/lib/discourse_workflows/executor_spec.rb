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
    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: user,
        enabled: true,
        nodes: [
          {
            "id" => "trigger-1",
            "type" => "trigger:topic_closed",
            "type_version" => "1.0",
            "name" => "Topic Closed",
            "position" => {
              "x" => 0,
              "y" => 0,
            },
            "position_index" => 0,
            "configuration" => {
            },
          },
          {
            "id" => "action-1",
            "type" => "action:topic_tags",
            "type_version" => "1.0",
            "name" => "Topic Tags",
            "position" => {
              "x" => 200,
              "y" => 0,
            },
            "position_index" => 1,
            "configuration" => {
              "topic_id" => "={{ trigger.topic_id }}",
              "tag_names" => tag.name,
            },
          },
        ],
        connections: [
          {
            "source_node_id" => "trigger-1",
            "target_node_id" => "action-1",
            "source_output" => "main",
          },
        ],
      )

    workflow
  end

  describe "#run" do
    it "executes a simple trigger -> action workflow" do
      workflow = build_workflow
      trigger_node = workflow.find_node("trigger-1")
      trigger_data = { topic_id: topic.id, tags: topic.tags.pluck(:name) }

      executor = described_class.new(workflow, trigger_node["id"], trigger_data)
      execution = executor.run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags).to include(tag)
    end

    it "creates an execution record" do
      workflow = build_workflow
      trigger_node = workflow.find_node("trigger-1")
      trigger_data = { topic_id: topic.id, tags: topic.tags.pluck(:name) }

      executor = described_class.new(workflow, trigger_node["id"], trigger_data)

      expect { executor.run }.to change { DiscourseWorkflows::Execution.count }.by(1)
    end

    it "stores context with item arrays in the execution" do
      workflow = build_workflow
      trigger_node = workflow.find_node("trigger-1")
      trigger_data = { topic_id: topic.id, tags: topic.tags.pluck(:name) }

      executor = described_class.new(workflow, trigger_node["id"], trigger_data)
      execution = executor.run

      ed = execution.execution_data.context_data
      expect(ed["Topic Closed"]).to be_an(Array)

      topic_tags_output = ed["Topic Tags"]
      expect(topic_tags_output).to be_an(Array)
      expect(topic_tags_output.first["json"]["tag_names"]).to eq([tag.name])
    end

    it "handles errors gracefully" do
      workflow = build_workflow
      trigger_node = workflow.find_node("trigger-1")
      trigger_data = { topic_id: -999, tags: [] }

      executor = described_class.new(workflow, trigger_node["id"], trigger_data)
      execution = executor.run

      expect(execution).to have_attributes(status: "error", error: be_present)
    end

    it "fails when trigger node is not in the snapshot" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
          ],
          connections: [],
        )

      executor = described_class.new(workflow, "trigger-1", {})
      workflow.update!(nodes: [])

      execution = executor.run

      expect(execution).to have_attributes(
        status: "error",
        error: include("not found in workflow snapshot"),
      )
    end

    it "follows the correct branch of a condition node" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "condition-1",
              "type" => "condition:if",
              "type_version" => "1.0",
              "name" => "Has Bug Tag",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
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
              },
            },
            {
              "id" => "action-true",
              "type" => "action:topic_tags",
              "type_version" => "1.0",
              "name" => "Tag Resolved",
              "position" => {
                "x" => 400,
                "y" => 0,
              },
              "position_index" => 2,
              "configuration" => {
                "topic_id" => "={{ trigger.topic_id }}",
                "tag_names" => tag.name,
              },
            },
            {
              "id" => "action-false",
              "type" => "action:topic_tags",
              "type_version" => "1.0",
              "name" => "Tag Needs Review",
              "position" => {
                "x" => 400,
                "y" => 200,
              },
              "position_index" => 3,
              "configuration" => {
                "topic_id" => "={{ trigger.topic_id }}",
                "tag_names" => false_tag.name,
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "condition-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "condition-1",
              "target_node_id" => "action-true",
              "source_output" => "true",
            },
            {
              "source_node_id" => "condition-1",
              "target_node_id" => "action-false",
              "source_output" => "false",
            },
          ],
        )

      trigger_data = { topic_id: topic.id, tags: %w[bug help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags.map(&:name)).to include(tag.name)
      expect(topic.reload.tags.map(&:name)).not_to include("needs-review")
    end

    it "continues execution when filter passes" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "filter-1",
              "type" => "condition:filter",
              "type_version" => "1.0",
              "name" => "Has Bug Tag",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
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
              },
            },
            {
              "id" => "action-1",
              "type" => "action:topic_tags",
              "type_version" => "1.0",
              "name" => "Topic Tags",
              "position" => {
                "x" => 400,
                "y" => 0,
              },
              "position_index" => 2,
              "configuration" => {
                "topic_id" => "={{ trigger.topic_id }}",
                "tag_names" => tag.name,
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "filter-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "filter-1",
              "target_node_id" => "action-1",
              "source_output" => "true",
            },
          ],
        )

      trigger_data = { topic_id: topic.id, tags: %w[bug help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags.map(&:name)).to include(tag.name)
    end

    it "supports $json expressions in filter conditions" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "filter-1",
              "type" => "condition:filter",
              "type_version" => "1.0",
              "name" => "Has Bug Tag",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
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
              },
            },
            {
              "id" => "action-1",
              "type" => "action:topic_tags",
              "type_version" => "1.0",
              "name" => "Topic Tags",
              "position" => {
                "x" => 400,
                "y" => 0,
              },
              "position_index" => 2,
              "configuration" => {
                "topic_id" => "={{ trigger.topic_id }}",
                "tag_names" => tag.name,
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "filter-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "filter-1",
              "target_node_id" => "action-1",
              "source_output" => "true",
            },
          ],
        )

      trigger_data = { topic_id: topic.id, tags: %w[bug help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags.map(&:name)).to include(tag.name)

      filter_step = execution.execution_data.find_step(node_id: "filter-1")
      expect(filter_step["metadata"].dig("conditions", 0, "left")).to eq(%w[bug help])
    end

    it "stops execution when filter does not pass" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "filter-1",
              "type" => "condition:filter",
              "type_version" => "1.0",
              "name" => "Has Bug Tag",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
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
              },
            },
            {
              "id" => "action-1",
              "type" => "action:topic_tags",
              "type_version" => "1.0",
              "name" => "Topic Tags",
              "position" => {
                "x" => 400,
                "y" => 0,
              },
              "position_index" => 2,
              "configuration" => {
                "topic_id" => "={{ trigger.topic_id }}",
                "tag_names" => tag.name,
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "filter-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "filter-1",
              "target_node_id" => "action-1",
              "source_output" => "true",
            },
          ],
        )

      trigger_data = { topic_id: topic.id, tags: %w[feature help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags.map(&:name)).not_to include(tag.name)
    end

    it "stores resolved configuration and result on execution steps" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "filter-1",
              "type" => "condition:filter",
              "type_version" => "1.0",
              "name" => "Check Tags",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
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
              },
            },
            {
              "id" => "action-1",
              "type" => "action:topic_tags",
              "type_version" => "1.0",
              "name" => "Topic Tags",
              "position" => {
                "x" => 400,
                "y" => 0,
              },
              "position_index" => 2,
              "configuration" => {
                "topic_id" => "={{ trigger.topic_id }}",
                "tag_names" => tag.name,
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "filter-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "filter-1",
              "target_node_id" => "action-1",
              "source_output" => "true",
            },
          ],
        )

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
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "filter-1",
              "type" => "condition:filter",
              "type_version" => "1.0",
              "name" => "Check Tags",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
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
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "filter-1",
              "source_output" => "main",
            },
          ],
        )

      trigger_data = { topic_id: topic.id, tags: %w[feature help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      filter_step = execution.execution_data.find_step(node_id: "filter-1")
      expect(filter_step["status"]).to eq("filtered")
    end

    it "routes rejected filter items to the false branch" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "filter-1",
              "type" => "condition:filter",
              "type_version" => "1.0",
              "name" => "Has Bug Tag",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
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
              },
            },
            {
              "id" => "action-false",
              "type" => "action:set_fields",
              "type_version" => "1.0",
              "name" => "Rejected",
              "position" => {
                "x" => 400,
                "y" => 200,
              },
              "position_index" => 2,
              "configuration" => {
                "include_input" => true,
                "mode" => "manual",
                "fields" => [{ "key" => "rejected", "value" => "yes", "type" => "string" }],
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "filter-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "filter-1",
              "target_node_id" => "action-false",
              "source_output" => "false",
            },
          ],
        )

      trigger_data = { topic_id: topic.id, tags: %w[feature help] }
      execution = described_class.new(workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")
      expect(execution.execution_data.find_step(node_id: "action-false")).to be_present
      expect(execution.execution_data.context_data["Rejected"].first.dig("json", "rejected")).to eq(
        "yes",
      )
    end

    it "skips disabled workflows" do
      workflow = build_workflow
      workflow.update!(enabled: false)
      trigger_data = { topic_id: topic.id, tags: topic.tags.pluck(:name) }

      executor = described_class.new(workflow, "trigger-1", trigger_data)
      execution = executor.run

      expect(execution.status).to eq("skipped")
    end

    it "records an error step for unknown node types" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "unknown-1",
              "type" => "action:nonexistent_type",
              "type_version" => "1.0",
              "name" => "Bad Node",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "unknown-1",
              "source_output" => "main",
            },
          ],
        )

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

      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "http-1",
              "type" => "action:http_request",
              "type_version" => "1.0",
              "name" => "HTTP Request",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
                "method" => "GET",
                "url" => "https://api.example.com/test",
                "authentication" => "none",
                "headers" => [
                  { "key" => "Authorization", "value" => "Bearer secret123" },
                  { "key" => "Content-Type", "value" => "application/json" },
                  { "key" => "X-Api-Key", "value" => "my-secret-key" },
                ],
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "http-1",
              "source_output" => "main",
            },
          ],
        )

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
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: user,
          enabled: true,
          nodes: [
            {
              "id" => "trigger-1",
              "type" => "trigger:topic_closed",
              "type_version" => "1.0",
              "name" => "Topic Closed",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "code-1",
              "type" => "action:code",
              "type_version" => "1.0",
              "name" => "Code",
              "position" => {
                "x" => 200,
                "y" => 0,
              },
              "position_index" => 1,
              "configuration" => {
                "code" => "throw new Error('x'.repeat(2000));",
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "code-1",
              "source_output" => "main",
            },
          ],
        )

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

        workflow =
          Fabricate(
            :discourse_workflows_workflow,
            created_by: user,
            enabled: true,
            nodes: [
              {
                "id" => "trigger-1",
                "type" => "trigger:topic_closed",
                "type_version" => "1.0",
                "name" => "Topic Closed",
                "position" => {
                  "x" => 0,
                  "y" => 0,
                },
                "position_index" => 0,
                "configuration" => {
                },
              },
            ],
            connections: [],
          )

        trigger_data = { topic_id: topic.id, tags: [] }

        first_execution = described_class.new(workflow, "trigger-1", trigger_data).run
        expect(first_execution.status).to eq("success")

        second_execution = described_class.new(workflow, "trigger-1", trigger_data).run
        expect(second_execution.status).to eq("rate_limited")
      end
    end
  end
end
