# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::LikePost::V1 do
  fab!(:admin)
  fab!(:author, :user)
  fab!(:actor, :user)
  fab!(:post) { Fabricate(:post, user: author) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def like(post_id: post.id, actor_username: actor.username)
    execute_node(configuration: { "post_id" => post_id.to_s, "actor_username" => actor_username })
  end

  it "likes the post as the actor", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:like_created) { result = like }

    expect(result).to include(
      "post" => include("id" => post.id, "like_count" => 1),
      "actor" => include("id" => actor.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(events.map { |event| event[:params].first.user_id }).to eq([actor.id])
  end

  it "reports nothing changed when the actor already liked the post", :aggregate_failures do
    PostActionCreator.like(actor, post)

    result = nil
    events = DiscourseEvent.track_events(:like_created) { result = like }

    expect(result).to include("changed" => false, "post" => include("like_count" => 1))
    expect(events).to be_empty
  end

  it "rejects an actor who can't see the post" do
    private_post = Fabricate(:private_message_post)

    expect { like(post_id: private_post.id) }.to raise_error(Discourse::InvalidAccess)
    expect(private_post.reload.like_count).to eq(0)
  end

  it "refuses to like the actor's own post like the like button" do
    expect { like(actor_username: author.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(I18n.t("invalid_access"))}/,
    )
  end

  it "refuses to like a post in an archived topic" do
    post.topic.update!(archived: true)

    expect { like }.to raise_error(DiscourseWorkflows::NodeError)
    expect(post.reload.like_count).to eq(0)
  end

  it "fails for a deleted post" do
    post.trash!(admin)

    expect { like }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "likes each input item's post" do
    second_post = Fabricate(:post)

    output =
      execute_node_output(
        configuration: {
          "post_id" => "={{ $json.post_id }}",
          "actor_username" => actor.username,
        },
        input_items: [
          { "json" => { "post_id" => post.id } },
          { "json" => { "post_id" => second_post.id } },
        ],
      )

    expect(output.first.map { |item| item.dig("json", "post", "id") }).to eq(
      [post.id, second_post.id],
    )
    expect(
      PostAction.where(user: actor, post_action_type_id: PostActionType::LIKE_POST_ACTION_ID).pluck(
        :post_id,
      ),
    ).to contain_exactly(post.id, second_post.id)
  end

  it "runs Post liked workflows as the actor, with the post's author as user" do
    graph = build_workflow_graph { |builder| builder.node "liked", "trigger:post_liked" }
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)

    like

    job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.sole["args"].first
    expect(job["user_id"]).to eq(actor.id)
    expect(job["trigger_data"]).to include(
      "user" => include("id" => author.id),
      "actor" => include("id" => actor.id),
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::UnlikePost::V1 do
  fab!(:admin)
  fab!(:author, :user)
  fab!(:actor, :user)
  fab!(:post) { Fabricate(:post, user: author) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def unlike(post_id: post.id, actor_username: actor.username)
    execute_node(configuration: { "post_id" => post_id.to_s, "actor_username" => actor_username })
  end

  it "removes the actor's like", :aggregate_failures do
    PostActionCreator.like(actor, post)

    result = nil
    events = DiscourseEvent.track_events(:like_destroyed) { result = unlike }

    expect(result).to include(
      "post" => include("id" => post.id, "like_count" => 0),
      "actor" => include("id" => actor.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(events.map { |event| event[:params].first.user_id }).to eq([actor.id])
  end

  it "reports nothing changed when the actor hasn't liked the post", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:like_destroyed) { result = unlike }

    expect(result).to include("changed" => false)
    expect(events).to be_empty
  end

  it "reports nothing changed when a staff actor's like was already taken back",
     :aggregate_failures do
    PostActionCreator.like(Discourse.system_user, post)
    PostActionDestroyer.destroy(Discourse.system_user, post, :like)

    result = nil
    events =
      DiscourseEvent.track_events(:like_destroyed) do
        result = unlike(actor_username: Discourse.system_user.username)
      end

    expect(result).to include("changed" => false)
    expect(events).to be_empty
  end

  it "rejects an actor who can't see the post when there's no like to remove" do
    private_post = Fabricate(:private_message_post)

    expect { unlike(post_id: private_post.id) }.to raise_error(Discourse::InvalidAccess)
  end

  it "keeps a like older than the undo window like the unlike button" do
    PostActionCreator.like(actor, post)

    freeze_time((SiteSetting.post_undo_action_window_mins + 1).minutes.from_now) do
      expect { unlike }.to raise_error(
        DiscourseWorkflows::NodeError,
        /#{Regexp.escape(I18n.t("invalid_access"))}/,
      )
    end
    expect(post.reload.like_count).to eq(1)
  end

  it "keeps a like in an archived topic" do
    PostActionCreator.like(actor, post)
    post.topic.update!(archived: true)

    expect { unlike }.to raise_error(DiscourseWorkflows::NodeError)
    expect(post.reload.like_count).to eq(1)
  end

  it "leaves the change to a concurrent unlike by the same actor" do
    like = PostActionCreator.like(actor, post).post_action
    allow(PostActionDestroyer).to receive(:destroy).and_wrap_original do |original, *args|
      like.remove_act!(actor)
      original.call(*args)
    end

    expect(unlike).to include("changed" => false, "post" => include("like_count" => 0))
  end

  it "runs Post unliked workflows as the actor, with the post's author as user" do
    PostActionCreator.like(actor, post)
    graph = build_workflow_graph { |builder| builder.node "unliked", "trigger:post_unliked" }
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)

    unlike

    job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.sole["args"].first
    expect(job["user_id"]).to eq(actor.id)
    expect(job["trigger_data"]).to include(
      "user" => include("id" => author.id),
      "actor" => include("id" => actor.id),
    )
  end
end
