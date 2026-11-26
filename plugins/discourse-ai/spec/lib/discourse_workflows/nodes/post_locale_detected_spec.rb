# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostLocaleDetected::V1, discourse_workflows: true do
  before do
    enable_current_plugin
    graph = build_workflow_graph { |builder| builder.node "detected", described_class.identifier }
    Fabricate(
      :discourse_workflows_workflow,
      created_by: Fabricate(:admin),
      published: true,
      **graph,
    )
  end

  it "dispatches workflows with the detected post locale" do
    post = Fabricate(:post, locale: "fr")

    DiscourseEvent.trigger(:post_locale_detected, post, {})

    trigger_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.sole["args"].first["trigger_data"]
    expect(trigger_data.dig("post", "locale")).to eq("fr")
    expect(trigger_data.dig("user", "id")).to eq(post.user_id)
    expect(trigger_data).to match_node_output_schema(described_class)
  end

  it "does not dispatch workflows for posts created by workflows" do
    DiscourseEvent.trigger(:post_locale_detected, Fabricate(:post), { skip_workflows: true })

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
  end
end
