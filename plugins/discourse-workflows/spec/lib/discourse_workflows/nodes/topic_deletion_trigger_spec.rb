# frozen_string_literal: true

RSpec.shared_context "with a topic deletion workflow" do
  fab!(:admin)
  fab!(:author, :user)
  fab!(:category)
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic, user: author, category:, tags: [tag]) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def publish_workflow(configuration: {})
    graph =
      build_workflow_graph do |g|
        g.node "deletion-trigger", described_class.identifier, configuration:
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
  end

  def trigger_data
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first["trigger_data"] }
  end
end

RSpec.describe DiscourseWorkflows::Nodes::TopicDeleted::V1 do
  include_context "with a topic deletion workflow"

  describe "#output" do
    it "returns the deleted topic, its author and the actor" do
      PostDestroyer.new(admin, first_post).destroy

      output = described_class.new(Topic.with_deleted.find(topic.id), acting_user: admin).output

      expect(output).to include(
        topic: include(id: topic.id, first_post_id: first_post.id),
        user: include(id: author.id),
        actor: include(id: admin.id),
      )
      expect(output).to match_node_output_schema(described_class)
    end

    it "returns a null actor when the event carries none" do
      output = described_class.new(topic).output

      expect(output).to include(actor: nil)
      expect(output).to match_node_output_schema(described_class)
    end
  end

  it "runs once when staff delete a topic, with the user who deleted it" do
    publish_workflow

    PostDestroyer.new(admin, first_post).destroy

    expect(trigger_data.sole).to include(
      "topic" => include("id" => topic.id),
      "user" => include("id" => author.id),
      "actor" => include("id" => admin.id),
    )
  end

  it "doesn't run again when a deleted topic is deleted again" do
    PostDestroyer.new(admin, first_post).destroy
    publish_workflow

    PostDestroyer.new(admin, first_post.reload).destroy

    expect(trigger_data).to be_empty
  end

  it "waits until a topic its author deleted is actually removed, then runs as the system user" do
    publish_workflow

    PostDestroyer.new(author, first_post).destroy

    expect(topic.reload).not_to be_trashed
    expect(trigger_data).to be_empty

    freeze_time (SiteSetting.delete_removed_posts_after + 1).hours.from_now
    PostDestroyer.destroy_stubs

    expect(trigger_data.sole).to include(
      "topic" => include("id" => topic.id),
      "actor" => include("id" => Discourse.system_user.id),
    )
  end

  it "runs when a delete timer fires, as the timer's user" do
    publish_workflow
    timer = topic.set_or_create_timer(TopicTimer.types[:delete], 1, by_user: admin)

    freeze_time 2.hours.from_now
    Jobs::DeleteTopic.new.execute(topic_timer_id: timer.id)

    expect(trigger_data.sole).to include("actor" => include("id" => admin.id))
  end

  it "runs without an actor when a category deletion removes its about topic" do
    about_category = Fabricate(:category_with_definition)
    publish_workflow

    about_category.destroy!

    expect(trigger_data.sole).to include(
      "topic" => include("id" => about_category.topic_id),
      "actor" => nil,
    )
  end

  it "only runs for topics in the configured categories and with the configured tags" do
    publish_workflow(configuration: { "category_ids" => [category.id], "tag_names" => [tag.name] })
    other_category_topic = Fabricate(:topic_with_op, tags: [tag])
    untagged_topic = Fabricate(:topic_with_op, category:)

    [topic, other_category_topic, untagged_topic].each do |deleted|
      PostDestroyer.new(admin, deleted.ordered_posts.first).destroy
    end

    expect(trigger_data.map { |data| data.dig("topic", "id") }).to eq([topic.id])
  end
end

RSpec.describe DiscourseWorkflows::Nodes::TopicRecovered::V1 do
  include_context "with a topic deletion workflow"

  describe "#output" do
    it "returns the recovered topic, its author and the actor" do
      output = described_class.new(topic, acting_user: admin).output

      expect(output).to include(
        topic: include(id: topic.id),
        user: include(id: author.id),
        actor: include(id: admin.id),
      )
      expect(output).to match_node_output_schema(described_class)
    end
  end

  describe "#valid?" do
    it "only accepts the event fired when the topic leaves the trash" do
      expect(described_class.new(topic, acting_user: admin)).to be_valid
      expect(described_class.new(topic, acting_user: author, from_trash: false)).not_to be_valid
    end
  end

  it "runs once when staff recover a deleted topic, with the user who recovered it" do
    PostDestroyer.new(admin, first_post).destroy
    publish_workflow

    PostDestroyer.new(admin, first_post.reload).recover

    expect(trigger_data.sole).to include(
      "topic" => include("id" => topic.id),
      "user" => include("id" => author.id),
      "actor" => include("id" => admin.id),
    )
  end

  it "doesn't run when authors cancel their own pending deletion" do
    PostDestroyer.new(author, first_post).destroy
    publish_workflow

    PostDestroyer.new(author, first_post.reload).recover

    expect(first_post.reload.user_deleted).to eq(false)
    expect(trigger_data).to be_empty
  end

  it "doesn't run when authors fail to recover a topic that was really deleted" do
    PostDestroyer.new(author, first_post, delete_removed_posts_after: 0).destroy
    publish_workflow

    PostDestroyer.new(author, first_post.reload).recover

    expect(Topic.with_deleted.find(topic.id)).to be_trashed
    expect(trigger_data).to be_empty
  end

  it "runs when changing the owner brings back a topic deleted with its author" do
    PostDestroyer.new(admin, first_post).destroy
    first_post.reload.update_columns(user_id: nil)
    publish_workflow

    PostOwnerChanger.new(
      post_ids: [first_post.id],
      topic_id: topic.id,
      new_owner: Fabricate(:user),
      acting_user: admin,
    ).change_owner!

    expect(trigger_data.sole).to include("actor" => include("id" => admin.id))
  end

  it "only runs for topics in the configured categories" do
    other_topic = Fabricate(:topic_with_op, tags: [tag])
    [topic, other_topic].each { |t| PostDestroyer.new(admin, t.ordered_posts.first).destroy }
    publish_workflow(configuration: { "category_ids" => [category.id] })

    [topic, other_topic].each do |t|
      PostDestroyer.new(admin, Post.with_deleted.find_by(topic_id: t.id, post_number: 1)).recover
    end

    expect(trigger_data.map { |data| data.dig("topic", "id") }).to eq([topic.id])
  end
end
