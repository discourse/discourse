# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicSlowModeSet::V1 do
  fab!(:admin)
  fab!(:topic)

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def publish_workflow(configuration: {})
    graph =
      build_workflow_graph do |g|
        g.node "slow-mode-trigger", "trigger:topic_slow_mode_set", configuration:
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
  end

  def set_slow_mode(enabled_until: nil)
    Topic::UpdateSlowMode.call(
      guardian: admin.guardian,
      params: {
        topic_id: topic.id,
        seconds: 600,
        enabled_until:,
      },
    )
  end

  def trigger_data
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first["trigger_data"] }
  end

  describe "#output" do
    it "returns the topic, the slow mode and the actor", :aggregate_failures do
      topic.update!(slow_mode_seconds: 600)

      output = described_class.new(topic, Time.utc(2030, 1, 15, 8), acting_user: admin).output

      expect(output).to include(
        topic: include(id: topic.id),
        slow_mode_seconds: 600,
        slow_mode_enabled_until: "2030-01-15T08:00:00Z",
        actor: include(id: admin.id),
      )
      expect(output).to match_node_output_schema(described_class)
    end

    it "returns a null end time and actor when the event carries none" do
      output = described_class.new(topic, nil).output

      expect(output).to include(slow_mode_enabled_until: nil, actor: nil)
      expect(output).to match_node_output_schema(described_class)
    end
  end

  it "runs when slow mode is set, with the user who set it" do
    publish_workflow

    set_slow_mode(enabled_until: "2030-01-15T08:00:00Z")

    expect(trigger_data.sole).to include(
      "topic" => include("id" => topic.id),
      "slow_mode_seconds" => 600,
      "slow_mode_enabled_until" => "2030-01-15T08:00:00Z",
      "actor" => include("id" => admin.id),
    )
  end

  it "doesn't run when nothing changes" do
    set_slow_mode
    publish_workflow

    set_slow_mode

    expect(trigger_data).to be_empty
  end

  it "doesn't run for topics outside the configured categories" do
    publish_workflow(configuration: { "category_ids" => [Fabricate(:category).id] })

    set_slow_mode

    expect(trigger_data).to be_empty
  end
end

RSpec.describe DiscourseWorkflows::Nodes::TopicSlowModeCleared::V1 do
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, slow_mode_seconds: 600) }

  before do
    DiscourseWorkflows::WorkflowDependency.clear_cache!
    graph = build_workflow_graph { |g| g.node "cleared-trigger", "trigger:topic_slow_mode_cleared" }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
  end

  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def trigger_data
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.sole["args"].first["trigger_data"]
  end

  it "returns the topic and the actor" do
    output = described_class.new(topic, acting_user: admin).output

    expect(output).to include(topic: include(id: topic.id), actor: include(id: admin.id))
    expect(output).to match_node_output_schema(described_class)
  end

  it "runs when a moderator clears slow mode" do
    Topic::UpdateSlowMode.call(guardian: admin.guardian, params: { topic_id: topic.id, seconds: 0 })

    expect(trigger_data).to include(
      "topic" => include("id" => topic.id),
      "actor" => include("id" => admin.id),
    )
  end

  it "runs when slow mode expires, as the system user" do
    timer =
      Fabricate(:topic_timer, topic:, user: admin, status_type: TopicTimer.types[:clear_slow_mode])
    timer.update_columns(execute_at: 1.minute.ago)

    Jobs::ClearSlowMode.new.execute(topic_timer_id: timer.id)

    expect(trigger_data).to include(
      "topic" => include("id" => topic.id),
      "actor" => include("id" => Discourse.system_user.id),
    )
  end
end
