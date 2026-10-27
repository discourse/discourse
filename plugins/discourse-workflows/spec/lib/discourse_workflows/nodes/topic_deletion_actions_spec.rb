# frozen_string_literal: true

RSpec.shared_context "with a topic for the deletion actions" do
  fab!(:admin)
  fab!(:author, :user)
  fab!(:other_user, :user)
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def run(actor: admin)
    execute_node(configuration: { "topic_id" => topic.id.to_s, "actor_username" => actor.username })
  end

  def publish_workflow(trigger)
    graph = build_workflow_graph { |g| g.node "trigger", trigger }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
  end

  def trigger_data
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first["trigger_data"] }
  end
end

RSpec.describe DiscourseWorkflows::Nodes::DeleteTopic::V1 do
  include_context "with a topic for the deletion actions"

  it "deletes the topic through its first post", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:topic_trashed) { result = run }

    expect(topic.reload).to have_attributes(trashed?: true, deleted_by_id: admin.id)
    expect(first_post.reload).to be_trashed
    expect(events.map { |event| event[:params] }).to eq([[topic, { acting_user: admin }]])
    expect(result).to include(
      "changed" => true,
      "topic" => include("id" => topic.id, "first_post_id" => first_post.id),
    )
    expect(result).to match_node_output_schema(described_class)
  end

  it "deletes the topic for good when its author deletes it" do
    run(actor: author)

    expect(topic.reload).to be_trashed
  end

  it "reports nothing changed for a topic that is already deleted" do
    PostDestroyer.new(admin, first_post).destroy

    expect(run).to include("changed" => false, "topic" => include("id" => topic.id))
  end

  it "rejects an actor who can't delete the topic" do
    expect { run(actor: other_user) }.to raise_error(Discourse::InvalidAccess)

    expect(topic.reload).not_to be_trashed
  end

  it "runs Topic deleted workflows once" do
    publish_workflow("trigger:topic_deleted")

    run

    expect(trigger_data.sole).to include("actor" => include("id" => admin.id))
  end
end

RSpec.describe DiscourseWorkflows::Nodes::RecoverTopic::V1 do
  include_context "with a topic for the deletion actions"

  before { PostDestroyer.new(admin, first_post).destroy }

  it "recovers the topic and its first post", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:topic_recovered) { result = run }

    expect(topic.reload).not_to be_trashed
    expect(first_post.reload).not_to be_trashed
    expect(events.map { |event| event[:params] }).to eq([[topic, { acting_user: admin }]])
    expect(result).to include("changed" => true, "topic" => include("id" => topic.id))
    expect(result).to match_node_output_schema(described_class)
  end

  it "reports nothing changed for a topic that isn't deleted" do
    PostDestroyer.new(admin, first_post.reload).recover

    expect(run).to include("changed" => false)
  end

  it "runs Topic recovered workflows once" do
    publish_workflow("trigger:topic_recovered")

    run

    expect(trigger_data.sole).to include("actor" => include("id" => admin.id))
  end

  it "rejects an actor who can't recover the topic" do
    expect { run(actor: author) }.to raise_error(Discourse::InvalidAccess)

    expect(Topic.with_deleted.find(topic.id)).to be_trashed
  end
end

RSpec.describe DiscourseWorkflows::Nodes::Topic::V2 do
  it "doesn't take deletion operations" do
    expect(described_class.properties.dig(:operation, :options)).not_to include("delete", "recover")
  end
end
