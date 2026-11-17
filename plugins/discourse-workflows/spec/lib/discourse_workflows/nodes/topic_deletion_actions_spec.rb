# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Topic::V2 do
  fab!(:admin)
  fab!(:author, :user)
  fab!(:other_user, :user)
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def run(operation, actor: admin)
    execute_node(
      configuration: {
        "operation" => operation,
        "topic_id" => topic.id.to_s,
        "actor_username" => actor.username,
      },
    )
  end

  def publish_workflow(trigger)
    graph = build_workflow_graph { |g| g.node "trigger", trigger }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
  end

  def trigger_data
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first["trigger_data"] }
  end

  describe "with operation 'delete'" do
    it "deletes the topic through its first post", :aggregate_failures do
      result = nil
      events = DiscourseEvent.track_events(:topic_trashed) { result = run("delete") }

      expect(topic.reload).to have_attributes(trashed?: true, deleted_by_id: admin.id)
      expect(first_post.reload).to be_trashed
      expect(events.map { |event| event[:params] }).to eq([[topic, { acting_user: admin }]])
      expect(result).to include(
        "changed" => true,
        "topic" => include("id" => topic.id, "first_post_id" => first_post.id),
        "user" => include("id" => author.id),
      )
      expect(result).to match_node_output_schema(
        described_class,
        configuration: {
          "operation" => "delete",
        },
      )
    end

    it "deletes the topic for good when its author deletes it" do
      run("delete", actor: author)

      expect(topic.reload).to be_trashed
    end

    it "reports nothing changed for a topic that is already deleted" do
      PostDestroyer.new(admin, first_post).destroy

      expect(run("delete")).to include("changed" => false, "topic" => include("id" => topic.id))
    end

    it "rejects an actor who can't delete the topic" do
      expect { run("delete", actor: other_user) }.to raise_error(Discourse::InvalidAccess)

      expect(topic.reload).not_to be_trashed
    end

    it "runs Topic deleted workflows once" do
      publish_workflow("trigger:topic_deleted")

      run("delete")

      expect(trigger_data.sole).to include("actor" => include("id" => admin.id))
    end
  end

  describe "with operation 'recover'" do
    before { PostDestroyer.new(admin, first_post).destroy }

    it "recovers the topic and its first post", :aggregate_failures do
      result = nil
      events = DiscourseEvent.track_events(:topic_recovered) { result = run("recover") }

      expect(topic.reload).not_to be_trashed
      expect(first_post.reload).not_to be_trashed
      expect(events.map { |event| event[:params] }).to eq([[topic, { acting_user: admin }]])
      expect(result).to include("changed" => true, "topic" => include("id" => topic.id))
      expect(result).to match_node_output_schema(
        described_class,
        configuration: {
          "operation" => "recover",
        },
      )
    end

    it "reports nothing changed for a topic that isn't deleted" do
      PostDestroyer.new(admin, first_post.reload).recover

      expect(run("recover")).to include("changed" => false)
    end

    it "runs Topic recovered workflows once" do
      publish_workflow("trigger:topic_recovered")

      run("recover")

      expect(trigger_data.sole).to include("actor" => include("id" => admin.id))
    end

    it "rejects an actor who can't recover the topic" do
      expect { run("recover", actor: author) }.to raise_error(Discourse::InvalidAccess)

      expect(Topic.with_deleted.find(topic.id)).to be_trashed
    end
  end
end
