# frozen_string_literal: true

require "rails_helper"
require_relative "../../../discourse-workflows/spec/support/node_execution_helpers"

RSpec.describe DiscourseWorkflows::Nodes::Event::V1 do
  fab!(:admin)

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.enable_discourse_workflows = true
    DiscourseWorkflows::WorkflowDependency.clear_cache!
  end

  def create_event_post(closed: false)
    closed_attribute = closed ? ' closed="true"' : ""

    post =
      PostCreator.create!(
        admin,
        title: "Workflow event integration",
        raw:
          "[event start=\"2030-04-24 14:15\" end=\"2030-04-24 15:15\" timezone=\"UTC\"#{closed_attribute}]\n" \
            "Event description\n" \
            "[/event]",
      )

    post.reload
    post.association(:event).reload
    post
  end

  def execute_event_action(post, operation)
    execute_node(
      configuration: {
        "operation" => operation,
        "topic_id" => post.topic_id.to_s,
        "actor_username" => admin.username,
      },
    )
  end

  def post_edited_workflow_job_count
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.count do |job|
      job["args"].first["trigger_node_id"] == "post-edited-trigger"
    end
  end

  def publish_post_edited_workflow
    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        published: true,
        **build_workflow_graph { |graph| graph.node "post-edited-trigger", "trigger:post_edited" },
      )

    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
    workflow
  end

  it "closes an event through the real workflow execution context" do
    post = create_event_post

    expect(post.event).to be_present
    expect(post.event.closed?).to eq(false)

    result = execute_event_action(post, "close")

    post.reload
    post.association(:event).reload

    expect(post.raw).to include('closed="true"')
    expect(post.event.closed?).to eq(true)

    expect(result["event"]).to include(
      "id" => post.event.id,
      "post_id" => post.id,
      "topic_id" => post.topic_id,
      "closed" => true,
    )
  end

  it "opens an event through the real workflow execution context" do
    post = create_event_post(closed: true)

    expect(post.event).to be_present
    expect(post.event.closed?).to eq(true)

    result = execute_event_action(post, "open")

    post.reload
    post.association(:event).reload

    expect(post.raw).not_to match(/\sclosed\s*=/i)
    expect(post.event.closed?).to eq(false)

    expect(result["event"]).to include(
      "id" => post.event.id,
      "post_id" => post.id,
      "topic_id" => post.topic_id,
      "closed" => false,
    )
  end

  it "does not recursively trigger post edited workflows" do
    post = create_event_post
    publish_post_edited_workflow

    before_count = post_edited_workflow_job_count

    execute_event_action(post, "close")

    expect(post_edited_workflow_job_count).to eq(before_count)
    expect(post.reload.event.closed?).to eq(true)
  end
end
