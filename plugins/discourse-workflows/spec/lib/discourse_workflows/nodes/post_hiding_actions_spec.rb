# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::HidePost::V1 do
  fab!(:admin)
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }
  fab!(:post) { Fabricate(:post, topic:, user: author) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def hide(post_id: post.id, actor_username: moderator.username, flag_reason: "spam")
    execute_node(
      configuration: {
        "post_id" => post_id.to_s,
        "flag_reason" => flag_reason,
        "actor_username" => actor_username,
      },
    )
  end

  it "hides the post as the actor, telling its author why", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:post_hidden) { result = hide }

    expect(result).to include(
      "post" => include("id" => post.id, "hidden" => true),
      "actor" => include("id" => moderator.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(post.reload).to have_attributes(
      hidden: true,
      hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached],
    )
    expect(events.map { |event| event[:params] }).to eq(
      [[post, { acting_user: moderator, post_action_type_id: PostActionType.types[:spam] }]],
    )
    expect(Jobs::SendSystemMessage.jobs.sole["args"].first).to include(
      "user_id" => author.id,
      "message_type" => "post_hidden",
    )
  end

  it "reports nothing changed when the post is already hidden" do
    post.hide!(PostActionType.types[:off_topic])

    result = nil
    events = DiscourseEvent.track_events(:post_hidden) { result = hide }

    expect(result).to include("changed" => false)
    expect(events).to be_empty
  end

  it "hides a post hidden before so its author can't unhide it by editing" do
    post.hide!(PostActionType.types[:off_topic])
    post.unhide!

    hide

    expect(post.reload.hidden_reason_id).to eq(Post.hidden_reasons[:flag_threshold_reached_again])
  end

  it "unlists the topic when hiding its first post" do
    hide(post_id: first_post.id)

    expect(topic.reload).to have_attributes(
      visible: false,
      visibility_reason_id: Topic.visibility_reasons[:op_flag_threshold_reached],
    )
  end

  it "refuses actors who aren't staff, even when the post is already hidden", :aggregate_failures do
    expect { hide(actor_username: author.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(I18n.t("discourse_workflows.errors.post_hiding.not_allowed", username: author.username, post_id: post.id))}/,
    )
    expect(post.reload).not_to be_hidden

    post.hide!(PostActionType.types[:off_topic])
    expect { hide(actor_username: author.username) }.to raise_error(DiscourseWorkflows::NodeError)
  end

  it "rejects an actor who can't see the post" do
    private_post = Fabricate(:private_message_post)

    expect { hide(post_id: private_post.id) }.to raise_error(Discourse::InvalidAccess)
    expect(private_post.reload).not_to be_hidden
  end

  it "hides a post in a deleted topic, like staff can from the post menu" do
    topic.trash!(admin)

    expect(hide).to include("changed" => true)
    expect(post.reload).to be_hidden
  end

  it "fails for an unknown flag reason" do
    expect {
      execute_node(
        configuration: {
          "post_id" => post.id.to_s,
          "flag_reason" => "={{ $json.reason }}",
          "actor_username" => moderator.username,
        },
        item: {
          "json" => {
            "reason" => "like",
          },
        },
      )
    }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(I18n.t("discourse_workflows.errors.post_hiding.unknown_flag_reason", flag_reason: "like"))}/,
    )
    expect(post.reload).not_to be_hidden
  end

  it "runs Post hidden workflows as the actor, with the post's author as user" do
    graph = build_workflow_graph { |builder| builder.node "hidden", "trigger:post_hidden" }
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)

    hide

    job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.sole["args"].first
    expect(job["trigger_data"]).to include(
      "user" => include("id" => author.id),
      "actor" => include("id" => moderator.id),
      "flag_reason" => "spam",
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::UnhidePost::V1 do
  fab!(:admin)
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }
  fab!(:post) { Fabricate(:post, topic:, user: author) }

  def unhide(post_id: post.id, actor_username: moderator.username)
    execute_node(configuration: { "post_id" => post_id.to_s, "actor_username" => actor_username })
  end

  it "unhides the post as the actor", :aggregate_failures do
    post.hide!(PostActionType.types[:off_topic])

    result = nil
    events = DiscourseEvent.track_events(:post_unhidden) { result = unhide }

    expect(result).to include(
      "post" => include("id" => post.id, "hidden" => false),
      "actor" => include("id" => moderator.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(post.reload).not_to be_hidden
    expect(events.map { |event| event[:params] }).to eq([[post, { acting_user: moderator }]])
  end

  it "lists the topic again when unhiding a first post that unlisted it" do
    first_post.hide!(PostActionType.types[:off_topic])

    unhide(post_id: first_post.id)

    expect(topic.reload).to be_visible
  end

  it "reports nothing changed when the post isn't hidden" do
    result = nil
    events = DiscourseEvent.track_events(:post_unhidden) { result = unhide }

    expect(result).to include("changed" => false)
    expect(events).to be_empty
  end

  it "refuses actors who aren't staff, even when the post isn't hidden", :aggregate_failures do
    post.hide!(PostActionType.types[:off_topic])

    expect { unhide(actor_username: author.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(I18n.t("discourse_workflows.errors.post_hiding.not_allowed", username: author.username, post_id: post.id))}/,
    )
    expect(post.reload).to be_hidden

    post.unhide!
    expect { unhide(actor_username: author.username) }.to raise_error(DiscourseWorkflows::NodeError)
  end

  it "unhides a deleted post in a deleted topic, like staff can from the post menu" do
    post.hide!(PostActionType.types[:off_topic])
    post.trash!(admin)
    topic.trash!(admin)

    expect(unhide).to include("changed" => true)
    expect(Post.with_deleted.find(post.id)).not_to be_hidden
  end

  it "rejects a category moderator acting on a deleted post outside their categories" do
    group = Fabricate(:group)
    group_moderator = Fabricate(:user, groups: [group])
    Fabricate(:category_moderation_group, category: Fabricate(:category), group:)
    post.hide!(PostActionType.types[:off_topic])
    post.trash!(admin)

    expect { unhide(actor_username: group_moderator.username) }.to raise_error(
      Discourse::InvalidAccess,
    )
  end

  it "fails when the post no longer passes its validations" do
    post.hide!(PostActionType.types[:off_topic])
    post.update_columns(raw: "a" * (SiteSetting.max_post_length + 1))

    expect { unhide }.to raise_error(
      DiscourseWorkflows::NodeError,
      /#{Regexp.escape(I18n.t("discourse_workflows.errors.post_hiding.unhide_failed", post_id: post.id, errors: ""))}/,
    )
    expect(post.reload).to be_hidden
  end
end
