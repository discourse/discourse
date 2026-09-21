# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:admin)

  let(:manifest) do
    File.read(Rails.root.join("plugins/discourse-workflows/docs/examples/node-packs/jev.json"))
  end
  let!(:pack) do
    DiscourseWorkflows::NodePack::Install.call(
      params: {
        manifest:,
        approved_destinations: ["https://api.typesafe.ai"],
      },
      guardian: admin.guardian,
    )[
      :node_pack
    ]
  end

  before do
    DiscourseWorkflows::NodePack::Update.call(
      params: {
        node_pack_id: pack.id,
        enabled: false,
      },
      guardian: admin.guardian,
    )
  end

  it "fails closed before pinned data, validation, requests, or downstream execution" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual"
        builder.node "choice-1", "action:jev.choice"
        builder.node "log-1", "action:log", configuration: { "message" => "should not run" }
        builder.chain "trigger-1", "choice-1", "log-1"
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

    options = described_class::ExecutionOptions.new(execution_mode: :manual, draft_execution: true)
    execution = described_class.new(workflow, "trigger-1", {}, options).run
    expect(execution).to have_attributes(status: "error")
    steps = DiscourseWorkflows::ExecutionData.find_by!(execution_id: execution.id).steps_array

    expect(steps.map { |step| [step["node_id"], step["status"]] }).to eq(
      [%w[trigger-1 success], %w[choice-1 error]],
    )
    expect(steps.last["error"]).to include("disabled")
    expect(a_request(:post, "https://api.typesafe.ai/v1/systemone")).not_to have_been_made
  end

  it "fails missing pack versions before pinned data or downstream execution" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:manual"
        builder.node "choice-1", "action:jev.choice"
        builder.node "log-1", "action:log", configuration: { "message" => "should not run" }
        builder.chain "trigger-1", "choice-1", "log-1"
      end
    graph[:nodes].find { |node| node["id"] == "choice-1" }["typeVersion"] = "99.0"
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    options = described_class::ExecutionOptions.new(execution_mode: :manual, draft_execution: true)

    execution = described_class.new(workflow, "trigger-1", {}, options).run
    steps = DiscourseWorkflows::ExecutionData.find_by!(execution_id: execution.id).steps_array

    expect(execution).to have_attributes(status: "error")
    expect(steps.map { |step| [step["node_id"], step["status"]] }).to eq(
      [%w[trigger-1 success], %w[choice-1 error]],
    )
    expect(steps.last["error"]).to include("no longer installed")
  end

  it "fails removed pack nodes instead of completing a child workflow" do
    DiscourseWorkflows::NodePack::Remove.call(
      params: {
        node_pack_id: pack.id,
      },
      guardian: admin.guardian,
    )
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:workflow_call"
        builder.node "choice-1", "action:jev.choice"
        builder.chain "trigger-1", "choice-1"
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    options =
      described_class::ExecutionOptions.new(workflow_call_child: true, draft_execution: true)

    execution = described_class.new(workflow, "trigger-1", {}, options).run

    expect(execution).to have_attributes(status: "error")
    expect(execution.error).to include("no longer installed")
  end
end
