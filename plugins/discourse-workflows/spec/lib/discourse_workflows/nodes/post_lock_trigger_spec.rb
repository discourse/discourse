# frozen_string_literal: true

RSpec.shared_context "with a post lock workflow" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:category)
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic, user: author, category:, tags: [tag]) }
  fab!(:post) { Fabricate(:post, topic:, user: author) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def publish_workflow(configuration: {})
    graph =
      build_workflow_graph { |g| g.node "lock-trigger", described_class.identifier, configuration: }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
  end

  def trigger_data
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first["trigger_data"] }
  end
end

RSpec.describe DiscourseWorkflows::Nodes::PostLocked::V1 do
  include_context "with a post lock workflow"

  it "outputs the post, its topic, its author and who locked it, from the event" do
    event = DiscourseEvent.track_events(:post_locked) { PostLocker.new(post, moderator).lock }.sole

    output = described_class.new(*event[:params]).output

    expect(output).to include(
      post: include(id: post.id),
      topic: include(id: topic.id),
      user: include(id: author.id),
      actor: include(id: moderator.id),
    )
    expect(output).to match_node_output_schema(described_class)
  end

  it "has no actor when the event doesn't say who locked the post" do
    expect(described_class.new(post).output).to include(actor: nil, user: include(id: author.id))
  end

  it "runs once as the staff member who locked the post" do
    publish_workflow

    PostLocker.new(post, moderator).lock
    PostLocker.new(post, admin).lock

    expect(trigger_data.sole).to include(
      "post" => include("id" => post.id),
      "user" => include("id" => author.id),
      "actor" => include("id" => moderator.id),
    )
  end

  it "only runs for posts in the configured categories, tags and topics" do
    publish_workflow(
      configuration: {
        "category_ids" => [category.id],
        "tag_names" => [tag.name],
        "topic_ids" => [topic.id],
      },
    )
    other_post = Fabricate(:post, topic:)
    other_category_post = Fabricate(:post, topic: Fabricate(:topic, tags: [tag]))
    untagged_post = Fabricate(:post, topic: Fabricate(:topic, category:))

    [post, other_post, other_category_post, untagged_post].each do |locked|
      PostLocker.new(locked, moderator).lock
    end

    expect(trigger_data.map { |data| data.dig("post", "id") }).to contain_exactly(
      post.id,
      other_post.id,
    )
  end

  it "ignores personal messages unless the topic type says otherwise" do
    publish_workflow
    pm_post = Fabricate(:private_message_post)

    PostLocker.new(pm_post, admin).lock
    expect(trigger_data).to be_empty

    DiscourseWorkflows::WorkflowDependency.clear_cache!
    publish_workflow(configuration: { "topic_type" => "personal_messages" })
    PostLocker.new(pm_post, admin).unlock
    PostLocker.new(pm_post, admin).lock

    expect(trigger_data.map { |data| data.dig("post", "id") }).to eq([pm_post.id])
  end

  it "ignores whispers and small actions" do
    publish_workflow
    whisper = Fabricate(:post, topic:, post_type: Post.types[:whisper])
    small_action = Fabricate(:post, topic:, post_type: Post.types[:small_action])

    [whisper, small_action].each { |locked| PostLocker.new(locked, admin).lock }

    expect(trigger_data).to be_empty
  end

  it "runs for a post in a deleted topic" do
    publish_workflow
    topic.trash!(admin)

    PostLocker.new(Post.find(post.id), admin).lock

    expect(trigger_data.sole).to include("topic" => include("id" => topic.id))
  end
end

RSpec.describe DiscourseWorkflows::Nodes::PostUnlocked::V1 do
  include_context "with a post lock workflow"

  it "runs once as the staff member who unlocked the post" do
    PostLocker.new(post, admin).lock
    publish_workflow

    PostLocker.new(post, moderator).unlock
    PostLocker.new(post, moderator).unlock

    expect(trigger_data.sole).to include(
      "post" => include("id" => post.id),
      "user" => include("id" => author.id),
      "actor" => include("id" => moderator.id),
    )
  end

  it "matches its output contract" do
    PostLocker.new(post, admin).lock
    event =
      DiscourseEvent.track_events(:post_unlocked) { PostLocker.new(post, moderator).unlock }.sole

    expect(described_class.new(*event[:params]).output).to match_node_output_schema(described_class)
  end
end
