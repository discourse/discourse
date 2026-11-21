# frozen_string_literal: true

require "rails_helper"
require_relative "../../../discourse-workflows/spec/support/node_execution_helpers"

RSpec.describe DiscourseWorkflows::Nodes::Event::V1 do
  fab!(:admin)
  fab!(:attendee, :user)

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.enable_discourse_workflows = true
    DiscourseWorkflows::WorkflowDependency.clear_cache!
  end

  def create_event_post(attributes: "", description: "Event description")
    post =
      PostCreator.create!(
        admin,
        title: "Workflow event integration",
        raw:
          "[event start=\"2030-04-24 14:15\" end=\"2030-04-24 15:15\" timezone=\"UTC\"#{attributes}]\n" \
            "#{description}\n" \
            "[/event]",
      )

    post.reload
    post.association(:event).reload
    post
  end

  def execute_event_action(post, operation)
    configuration = {
      "operation" => operation,
      "topic_id" => post.topic_id.to_s,
      "actor_username" => admin.username,
    }

    result = execute_node(configuration:)
    expect(result).to match_node_output_schema(described_class, configuration:)
    result
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

  it "sets an event author to going from a post created workflow" do
    graph =
      build_workflow_graph do |g|
        g.node "post-created-attendance", "trigger:post_created"

        g.node "first-post-only",
               "condition:if",
               configuration: {
                 "conditions" => [
                   {
                     "id" => "1",
                     "leftValue" => "={{ $json.post.post_number }}",
                     "rightValue" => 1,
                     "operator" => {
                       "type" => "number",
                       "operation" => "equals",
                     },
                   },
                 ],
                 "combinator" => "and",
               }

        g.node "set-event-attendance",
               "action:event",
               configuration: {
                 "operation" => "set_attendance",
                 "topic_id" => "={{ $trigger.topic.id }}",
                 "attendee_username" => "={{ $trigger.user.username }}",
                 "attendance" => "going",
                 "actor_username" => "system",
               }

        g.chain "post-created-attendance", "first-post-only"
        g.connect "first-post-only", "set-event-attendance", output: "true"
      end

    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        name: "Event author attendance",
        **graph,
      )

    publish_workflow!(workflow)
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    post =
      PostCreator.create!(
        admin,
        title: "Automatically attend my event",
        raw:
          "[event start=\"2030-04-24 14:15\" end=\"2030-04-24 15:15\" " \
            "timezone=\"UTC\" status=\"public\"]\n" \
            "Event description\n" \
            "[/event]",
      )

    post.reload
    post.association(:event).reload

    # This assertion is deliberately before executing the workflow job.
    # It proves the Events post-created listener synchronized the event first.
    expect(post.event).to be_present
    expect(post.event.invitees.find_by(user_id: admin.id)).to be_nil

    job =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.find do |queued_job|
        args = queued_job["args"].first
        args["workflow_id"] == workflow.id && args["trigger_node_id"] == "post-created-attendance"
      end

    expect(job).to be_present

    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job["args"].first.symbolize_keys)

    invitee = post.event.invitees.find_by(user_id: admin.id)

    expect(invitee).to be_present
    expect(invitee.status).to eq(DiscourseEvents::Events::Invitee.statuses[:going])

    # Replies also emit post_created, but must not register their authors
    # as attendees. The first-post condition protects against that.
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    PostCreator.create!(attendee, topic_id: post.topic_id, raw: "A reply to the event topic")

    reply_job =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.find do |queued_job|
        args = queued_job["args"].first
        args["workflow_id"] == workflow.id && args["trigger_node_id"] == "post-created-attendance"
      end

    expect(reply_job).to be_present

    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(reply_job["args"].first.symbolize_keys)

    expect(post.event.invitees.find_by(user_id: attendee.id)).to be_nil
  end

  it "sets attendance as the system user for another user" do
    post = create_event_post(attributes: ' status="public"')

    expect(post.event.invitees.find_by(user_id: attendee.id)).to be_nil

    result =
      execute_node(
        configuration: {
          "operation" => "set_attendance",
          "topic_id" => post.topic_id.to_s,
          "attendee_username" => attendee.username,
          "attendance" => "going",
          "actor_username" => "system",
        },
      )

    invitee = post.event.invitees.find_by(user_id: attendee.id)

    expect(invitee).to be_present
    expect(invitee.status).to eq(DiscourseEvents::Events::Invitee.statuses[:going])
    expect(result).to match_node_output_schema(described_class)
    expect(result["event"]).to include(
      "id" => post.event.id,
      "post_id" => post.id,
      "topic_id" => post.topic_id,
    )
  end

  it "closes an event through the real workflow execution context" do
    post = create_event_post

    expect(post.event).to be_present
    expect(post.event.closed?).to eq(false)

    result = execute_event_action(post, "close")

    post.reload
    post.association(:event).reload

    expect(post.raw).to include("closed=true")
    expect(post.event.closed?).to eq(true)

    expect(result["event"]).to include(
      "id" => post.event.id,
      "post_id" => post.id,
      "topic_id" => post.topic_id,
      "closed" => true,
    )
  end

  it "opens an event through the real workflow execution context" do
    post = create_event_post(attributes: ' closed="true"')

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

  it "closes an event when its post contains a hashtag" do
    post = create_event_post(description: "Discuss in #general")

    expect(post.event).not_to be_closed

    execute_event_action(post, "close")

    post.reload
    post.association(:event).reload

    expect(post.event).to be_closed
    expect(post.raw).to include("Discuss in #general")
    expect(post.raw).to include("closed=true")
  end

  it "opens an event when its post contains a hashtag" do
    post = create_event_post(attributes: ' closed="true"', description: "Discuss in #general")

    expect(post.event).to be_closed

    execute_event_action(post, "open")

    post.reload
    post.association(:event).reload

    expect(post.event).not_to be_closed
    expect(post.raw).to include("Discuss in #general")
    expect(post.raw).not_to match(/\sclosed\s*=/i)
  end

  it "preserves quoted attributes when closing an event" do
    attributes = ' location="Room ] closed=true"'
    post = create_event_post(attributes:)

    execute_event_action(post, "close")

    expect(post.reload.raw).to include(attributes, " closed=true]")
    expect(post.event).to be_closed
  end

  it "preserves quoted attributes when opening an event" do
    attributes = ' location="Room ] closed=true"'
    post = create_event_post(attributes: attributes + ' closed="true"')
    expected_raw = post.raw.sub(' closed="true"', "")

    execute_event_action(post, "open")

    expect(post.reload.raw).to eq(expected_raw)
    expect(post.event).not_to be_closed
  end

  it "preserves Unicode-quoted attributes when closing an event" do
    attributes = " location=«Room ] closed=true»"
    post = create_event_post(attributes:)

    execute_event_action(post, "close")

    expect(post.reload.event).to be_closed
    expect(post.event.location).to eq("Room ] closed=true")
  end

  it "edits the event after a fenced BBCode example" do
    example = "```\n[event start=\"2030-04-24 14:15\"]\nExample\n[/event]\n```\n\n"
    post = create_event_post
    PostRevisor.new(post).revise!(admin, { raw: example + post.raw })

    execute_event_action(post, "close")

    expect(post.reload.raw).to start_with(example)
    expect(post.event).to be_closed
  end

  it "leaves an already closed event unchanged" do
    post = create_event_post(attributes: ' closed="true"')

    expect { execute_event_action(post, "close") }.not_to change {
      post.reload.attributes.slice("raw", "version")
    }
    expect(post.event).to be_closed
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
