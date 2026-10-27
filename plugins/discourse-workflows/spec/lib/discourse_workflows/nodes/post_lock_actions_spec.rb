# frozen_string_literal: true

RSpec.shared_context "with a post to lock" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:post) { Fabricate(:post, topic:, user: author) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def run_node(post_id: post.id, actor_username: moderator.username)
    execute_node(configuration: { "post_id" => post_id.to_s, "actor_username" => actor_username })
  end

  def staff_logs(action)
    UserHistory.where(action: UserHistory.actions[action])
  end
end

RSpec.describe DiscourseWorkflows::Nodes::LockPost::V1 do
  include_context "with a post to lock"

  it "locks the post as the actor", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:post_locked) { result = run_node }

    expect(result).to include(
      "post" => include("id" => post.id),
      "actor" => include("id" => moderator.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(post.reload.locked_by_id).to eq(moderator.id)
    expect(staff_logs(:post_locked).sole).to have_attributes(acting_user_id: moderator.id)
    expect(events.map { |event| event[:params] }).to eq([[post, { acting_user: moderator }]])
  end

  it "reports nothing changed when the post is already locked, without logging it again",
     :aggregate_failures do
    PostLocker.new(post, admin).lock

    result = nil
    events = DiscourseEvent.track_events(:post_locked) { result = run_node }

    expect(result).to include("changed" => false)
    expect(post.reload.locked_by_id).to eq(admin.id)
    expect(staff_logs(:post_locked).count).to eq(1)
    expect(events).to be_empty
  end

  it "refuses actors who aren't staff, even when the post is already locked", :aggregate_failures do
    expect { run_node(actor_username: author.username) }.to raise_error(Discourse::InvalidAccess)
    expect(post.reload).not_to be_locked

    PostLocker.new(post, admin).lock
    expect { run_node(actor_username: author.username) }.to raise_error(Discourse::InvalidAccess)
  end

  it "refuses a moderator who can't see the personal message" do
    pm_post = Fabricate(:private_message_post)

    expect { run_node(post_id: pm_post.id) }.to raise_error(Discourse::InvalidAccess)
    expect(pm_post.reload).not_to be_locked
  end

  it "locks a post in a deleted topic, like staff can from the post menu", :aggregate_failures do
    topic.trash!(admin)

    result = run_node

    expect(result).to include("changed" => true, "post" => include("topic_id" => topic.id))
    expect(post.reload).to be_locked
  end

  it "locks a deleted post" do
    post.trash!(admin)

    expect(run_node).to include("changed" => true)
    expect(Post.with_deleted.find(post.id)).to be_locked
  end

  it "fails for a post that doesn't exist" do
    expect { run_node(post_id: -1) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "runs Post locked workflows as the actor, with the post's author as user" do
    graph = build_workflow_graph { |builder| builder.node "locked", "trigger:post_locked" }
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)

    run_node

    job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.sole["args"].first
    expect(job["trigger_data"]).to include(
      "user" => include("id" => author.id),
      "actor" => include("id" => moderator.id),
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::UnlockPost::V1 do
  include_context "with a post to lock"

  it "unlocks the post as the actor", :aggregate_failures do
    PostLocker.new(post, admin).lock

    result = nil
    events = DiscourseEvent.track_events(:post_unlocked) { result = run_node }

    expect(result).to include(
      "post" => include("id" => post.id),
      "actor" => include("id" => moderator.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(post.reload).not_to be_locked
    expect(staff_logs(:post_unlocked).sole).to have_attributes(acting_user_id: moderator.id)
    expect(events.map { |event| event[:params] }).to eq([[post, { acting_user: moderator }]])
  end

  it "reports nothing changed when the post isn't locked, without logging it",
     :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:post_unlocked) { result = run_node }

    expect(result).to include("changed" => false)
    expect(staff_logs(:post_unlocked)).to be_empty
    expect(events).to be_empty
  end

  it "refuses actors who aren't staff, even when the post isn't locked", :aggregate_failures do
    PostLocker.new(post, admin).lock

    expect { run_node(actor_username: author.username) }.to raise_error(Discourse::InvalidAccess)
    expect(post.reload).to be_locked

    PostLocker.new(post, admin).unlock
    expect { run_node(actor_username: author.username) }.to raise_error(Discourse::InvalidAccess)
  end

  it "unlocks a post in a deleted topic, like staff can from the post menu" do
    PostLocker.new(post, admin).lock
    topic.trash!(admin)

    expect(run_node).to include("changed" => true)
    expect(post.reload).not_to be_locked
  end
end
