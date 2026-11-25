# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::TriggerDispatcher do
  fab!(:admin)

  let(:type) { "trigger:manual" }

  def set_fields_graph(source)
    build_workflow_graph do |builder|
      builder.node("start", "trigger:manual")
      builder.node(
        "set",
        "action:set_fields",
        name: "Set fields",
        configuration: {
          "mode" => "raw",
          "json_output" => { source: }.to_json,
        },
      )
      builder.connect("start", "set")
    end
  end

  def set_fields_output(execution)
    execution.execution_data.run_data["Set fields"].first["outputs"].first["items"].first["json"]
  end

  describe ".execute" do
    fab!(:workflow) do
      Fabricate(:discourse_workflows_workflow, published: true, **set_fields_graph("published"))
    end

    before { workflow.update!(nodes: set_fields_graph("draft")[:nodes]) }

    it "runs a published trigger as a normal execution of its version" do
      trigger =
        DiscourseWorkflows::PublishedTrigger.find(type:, workflow_id: workflow.id, node_id: "start")

      execution = described_class.execute(trigger, trigger_data: { "question" => "Hello" })

      expect(execution).to be_success.and be_normal
      expect(set_fields_output(execution)).to include("source" => "published")
    end

    it "runs a draft trigger as a manual execution of the unpublished graph" do
      trigger =
        DiscourseWorkflows::PublishedTrigger.find(
          type:,
          workflow_id: workflow.id,
          node_id: "start",
          draft: true,
          guardian: admin.guardian,
        )

      execution =
        described_class.execute(trigger, trigger_data: { "question" => "Hello" }, user: admin)

      expect(execution).to be_success.and be_manual
      expect(set_fields_output(execution)).to include("source" => "draft")
    end

    it "runs once for a job ID and returns that execution to later calls" do
      trigger =
        DiscourseWorkflows::PublishedTrigger.find(type:, workflow_id: workflow.id, node_id: "start")

      executions =
        2.times.map do
          described_class.execute(trigger, trigger_data: { "question" => "Hello" }, job_id: "job-1")
        end

      expect(executions.map(&:id).uniq).to eq([workflow.executions.sole.id])
    end
  end
end
