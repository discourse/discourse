# frozen_string_literal: true

RSpec.shared_context "with a post hiding workflow" do
  fab!(:admin)
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic, user: author, category:, tags: [tag]) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }
  fab!(:post) { Fabricate(:post, topic:, user: author) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def publish_workflow(configuration: {})
    graph =
      build_workflow_graph do |g|
        g.node "hiding-trigger", described_class.identifier, configuration:
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
  end

  def trigger_data
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first["trigger_data"] }
  end
end

RSpec.describe DiscourseWorkflows::Nodes::PostHidden::V1 do
  include_context "with a post hiding workflow"

  def hide_event
    DiscourseEvent.track_events(:post_hidden) { yield }.sole
  end

  it "outputs the post, its author, who hid it and why, from the event" do
    event = hide_event { post.hide!(PostActionType.types[:inappropriate], acting_user: moderator) }

    output = described_class.new(*event[:params]).output

    expect(output).to include(
      post: include(id: post.id),
      topic: include(id: topic.id),
      user: include(id: author.id),
      actor: include(id: moderator.id),
      hidden_reason: "flag_threshold_reached",
      flag_reason: "inappropriate",
    )
    expect(output).to match_node_output_schema(described_class)
  end

  it "has no flag reason when no flag hid the post" do
    author.update!(trust_level: TrustLevel[0])

    event =
      DiscourseEvent
        .track_events(:post_hidden) { UserSilencer.silence(author, admin) }
        .find { |hidden| hidden[:params].first == post }

    output = described_class.new(*event[:params]).output
    expect(output).to include(
      actor: include(id: admin.id),
      hidden_reason: "new_user_spam_threshold_reached",
      flag_reason: nil,
    )
    expect(output).to match_node_output_schema(described_class)
  end

  it "runs once as the system user when flags reach the threshold" do
    publish_workflow
    Reviewable.set_priorities(high: 3.0)
    SiteSetting.hide_post_sensitivity = Reviewable.sensitivities[:low]

    PostActionCreator.spam(Fabricate(:user, refresh_auto_groups: true), post)
    PostActionCreator.spam(Fabricate(:user, refresh_auto_groups: true), post)

    expect(trigger_data.sole).to include(
      "post" => include("id" => post.id),
      "user" => include("id" => author.id),
      "actor" => include("id" => Discourse.system_user.id),
      "flag_reason" => "spam",
    )
  end

  it "only runs for posts in the configured categories and with the configured tags" do
    publish_workflow(configuration: { "category_ids" => [category.id], "tag_names" => [tag.name] })
    other_category_post = Fabricate(:post, topic: Fabricate(:topic, tags: [tag]))
    untagged_post = Fabricate(:post, topic: Fabricate(:topic, category:))

    [post, other_category_post, untagged_post].each do |hidden|
      hidden.hide!(PostActionType.types[:spam], acting_user: moderator)
    end

    expect(trigger_data.map { |data| data.dig("post", "id") }).to contain_exactly(post.id)
  end

  it "ignores personal messages unless the topic type says otherwise" do
    publish_workflow
    pm_post = Fabricate(:private_message_post)

    pm_post.hide!(PostActionType.types[:spam], acting_user: moderator)

    expect(trigger_data).to be_empty
  end

  it "ignores whispers" do
    publish_workflow
    whisper = Fabricate(:post, topic:, post_type: Post.types[:whisper])

    whisper.hide!(PostActionType.types[:spam], acting_user: moderator)

    expect(trigger_data).to be_empty
  end

  it "isn't valid once the topic is gone" do
    Topic.where(id: topic.id).delete_all

    expect(described_class.new(Post.find(post.id), acting_user: moderator)).not_to be_valid
  end
end

RSpec.describe DiscourseWorkflows::Nodes::PostUnhidden::V1 do
  include_context "with a post hiding workflow"

  it "runs as the staff member unhiding the post, saying why it was hidden" do
    post.hide!(PostActionType.types[:spam])
    publish_workflow

    post.unhide!(acting_user: moderator)

    expect(trigger_data.sole).to include(
      "post" => include("id" => post.id),
      "user" => include("id" => author.id),
      "actor" => include("id" => moderator.id),
      "hidden_reason" => "flag_threshold_reached",
    )
  end

  it "runs as the author when they edit a post hidden by flags" do
    post.hide!(PostActionType.types[:spam])
    publish_workflow

    PostRevisor.new(post).revise!(
      author,
      { raw: "#{post.raw} with an edit by its author" },
      revised_at: post.updated_at + 11.minutes,
    )

    expect(trigger_data.sole).to include("actor" => include("id" => author.id))
  end

  it "doesn't run for a post that wasn't hidden" do
    publish_workflow

    post.unhide!(acting_user: moderator)

    expect(trigger_data).to be_empty
  end

  it "matches its output contract" do
    post.hide!(PostActionType.types[:spam])
    event =
      DiscourseEvent.track_events(:post_unhidden) { post.unhide!(acting_user: moderator) }.sole

    expect(described_class.new(*event[:params]).output).to match_node_output_schema(described_class)
  end
end
