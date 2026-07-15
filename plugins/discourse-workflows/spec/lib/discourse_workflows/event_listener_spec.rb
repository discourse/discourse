# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::EventListener do
  fab!(:user)
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:tag) { Fabricate(:tag, name: "matched") }
  fab!(:membership_group) { Fabricate(:group, name: "workflow_helpers", full_name: "Helpers") }
  fab!(:other_group) { Fabricate(:group, name: "workflow_others", full_name: "Others") }
  fab!(:badge) { Fabricate(:badge, name: "Workflow badge") }
  fab!(:other_badge) { Fabricate(:badge, name: "Other workflow badge") }

  before do
    SiteSetting.tagging_enabled = true
    DiscourseWorkflows::WorkflowDependency.clear_cache!
  end

  it "enqueues a job when a matching event fires" do
    graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)

    topic.update_status("closed", true, admin)

    job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job).to be_present
    expect(job["args"].first["trigger_node_id"]).to eq("trigger-1")
    expect(job["args"].first["workflow_id"]).to eq(workflow.id)
  end

  it "does not enqueue when plugin is disabled" do
    SiteSetting.enable_discourse_workflows = false

    graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_closed" }
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)

    topic.update_status("closed", true, admin)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_node_id"] == "trigger-1"
      end
    expect(jobs).to be_empty
  end

  it "only enqueues topic closed workflows matching the category and tags" do
    topic.tags << tag
    create_published_workflow(
      "matching-trigger",
      "trigger:topic_closed",
      configuration: {
        "category_id" => category.id.to_s,
        "tag_names" => [tag.name],
      },
    )
    create_published_workflow(
      "category-mismatch",
      "trigger:topic_closed",
      configuration: {
        "category_id" => other_category.id.to_s,
      },
    )
    create_published_workflow(
      "tag-mismatch",
      "trigger:topic_closed",
      configuration: {
        "tag_names" => ["missing"],
      },
    )

    topic.update_status("closed", true, admin)

    expect(enqueued_trigger_node_ids).to include("matching-trigger")
    expect(enqueued_trigger_node_ids).not_to include("category-mismatch", "tag-mismatch")
  end

  it "only enqueues topic created workflows matching the category and tags" do
    create_post(topic: topic)
    topic.tags << tag
    create_published_workflow(
      "matching-trigger",
      "trigger:topic_created",
      configuration: {
        "category_id" => category.id.to_s,
        "tag_names" => [tag.name],
      },
    )
    create_published_workflow(
      "category-mismatch",
      "trigger:topic_created",
      configuration: {
        "category_id" => other_category.id.to_s,
      },
    )
    create_published_workflow(
      "tag-mismatch",
      "trigger:topic_created",
      configuration: {
        "tag_names" => ["missing"],
      },
    )

    described_class.handle(DiscourseWorkflows::Nodes::TopicCreated::V1, topic)

    expect(enqueued_trigger_node_ids).to include("matching-trigger")
    expect(enqueued_trigger_node_ids).not_to include("category-mismatch", "tag-mismatch")
  end

  it "only enqueues post created workflows matching the topic category and tags" do
    topic.tags << tag
    create_published_workflow(
      "matching-trigger",
      "trigger:post_created",
      configuration: {
        "category_id" => category.id.to_s,
        "tag_names" => [tag.name],
      },
    )
    create_published_workflow(
      "category-mismatch",
      "trigger:post_created",
      configuration: {
        "category_id" => other_category.id.to_s,
      },
    )
    create_published_workflow(
      "tag-mismatch",
      "trigger:post_created",
      configuration: {
        "tag_names" => ["missing"],
      },
    )

    post = create_post(topic: topic)
    described_class.handle(DiscourseWorkflows::Nodes::PostCreated::V1, post)

    expect(enqueued_trigger_node_ids).to include("matching-trigger")
    expect(enqueued_trigger_node_ids).not_to include("category-mismatch", "tag-mismatch")
  end

  it "only enqueues post edited workflows matching topic category, tags, and trust levels" do
    topic.tags << tag
    create_published_workflow(
      "matching-trigger",
      "trigger:post_edited",
      configuration: {
        "category_id" => category.id.to_s,
        "tag_names" => [tag.name],
        "trust_levels" => ["1"],
      },
    )
    create_published_workflow(
      "trust-level-mismatch",
      "trigger:post_edited",
      configuration: {
        "trust_levels" => ["2"],
      },
    )
    create_published_workflow(
      "tag-mismatch",
      "trigger:post_edited",
      configuration: {
        "tag_names" => ["missing"],
      },
    )

    post = create_post(user: Fabricate(:user, trust_level: TrustLevel[1]), category: category)
    post.topic.tags << tag
    described_class.handle(DiscourseWorkflows::Nodes::PostEdited::V1, post, "<p>Cooked</p>")

    expect(enqueued_trigger_node_ids).to include("matching-trigger")
    expect(enqueued_trigger_node_ids).not_to include("trust-level-mismatch", "tag-mismatch")
  end

  it "enqueues post edited workflows from the post edited event" do
    post = create_post(user: Fabricate(:user, trust_level: TrustLevel[1]), category: category)
    create_published_workflow("post-edited-trigger", "trigger:post_edited")

    PostRevisor.new(post).revise!(admin, raw: "Edited by admin")

    expect(enqueued_trigger_node_ids).to include("post-edited-trigger")
  end

  it "does not enqueue post edited workflows when the revision skips workflows" do
    post = create_post(user: Fabricate(:user, trust_level: TrustLevel[1]), category: category)
    create_published_workflow("post-edited-trigger", "trigger:post_edited")

    PostRevisor.new(post).revise!(admin, { raw: "Edited by workflow" }, skip_workflows: true)

    expect(enqueued_trigger_node_ids).not_to include("post-edited-trigger")
  end

  it "only enqueues reviewable approved workflows matching the reviewable type" do
    create_published_workflow(
      "matching-trigger",
      "trigger:reviewable_approved",
      configuration: {
        "reviewable_types" => ["ReviewableFlaggedPost"],
      },
    )
    create_published_workflow(
      "type-mismatch",
      "trigger:reviewable_approved",
      configuration: {
        "reviewable_types" => ["ReviewableUser"],
      },
    )

    reviewable = Fabricate(:reviewable_flagged_post)
    described_class.handle(DiscourseWorkflows::Nodes::ReviewableApproved::V1, :approved, reviewable)

    expect(enqueued_trigger_node_ids).to include("matching-trigger")
    expect(enqueued_trigger_node_ids).not_to include("type-mismatch")
  end

  it "only enqueues badge granted workflows matching the badge" do
    create_published_workflow(
      "matching-badge-trigger",
      "trigger:badge_granted",
      configuration: {
        "badge_id" => badge.id.to_s,
      },
    )
    create_published_workflow(
      "badge-mismatch-trigger",
      "trigger:badge_granted",
      configuration: {
        "badge_id" => other_badge.id.to_s,
      },
    )
    create_published_workflow("any-badge-trigger", "trigger:badge_granted")

    BadgeGranter.grant(badge, user, granted_by: admin)

    expect(enqueued_trigger_node_ids).to include("matching-badge-trigger", "any-badge-trigger")
    expect(enqueued_trigger_node_ids).not_to include("badge-mismatch-trigger")

    trigger_data = trigger_data_for("matching-badge-trigger")
    expect(trigger_data).to include(
      "user" => include("id" => user.id, "username" => user.username),
      "badge" => include("id" => badge.id, "name" => badge.name),
    )
  end

  it "only enqueues user seen workflows matching the trigger setting" do
    seen_at = Time.zone.now
    user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)

    create_published_workflow("matching-trigger", "trigger:user_seen")
    create_published_workflow(
      "returning-user-trigger",
      "trigger:user_seen",
      configuration: {
        "trigger_on_first_seen" => false,
        "trigger_on_not_seen_for_more_than" => true,
        "not_seen_for_amount" => 1,
        "not_seen_for_unit" => "days",
      },
    )
    create_published_workflow(
      "combined-trigger",
      "trigger:user_seen",
      configuration: {
        "trigger_on_first_seen" => true,
        "trigger_on_not_seen_for_more_than" => true,
        "not_seen_for_amount" => 1,
        "not_seen_for_unit" => "days",
      },
    )

    described_class.handle(DiscourseWorkflows::Nodes::UserSeen::V1, user, nil)

    expect(enqueued_trigger_node_ids).to contain_exactly("matching-trigger", "combined-trigger")
    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["user_id"]).to eq(
      user.id,
    )
  end

  it "enqueues user seen workflows for returning users" do
    previous_seen_at = 2.days.ago
    user.update_columns(first_seen_at: 1.month.ago, last_seen_at: Time.zone.now)

    create_published_workflow("new-user-trigger", "trigger:user_seen")
    create_published_workflow(
      "returning-user-trigger",
      "trigger:user_seen",
      configuration: {
        "trigger_on_first_seen" => false,
        "trigger_on_not_seen_for_more_than" => true,
        "not_seen_for_amount" => 1,
        "not_seen_for_unit" => "days",
      },
    )
    create_published_workflow(
      "combined-trigger",
      "trigger:user_seen",
      configuration: {
        "trigger_on_first_seen" => true,
        "trigger_on_not_seen_for_more_than" => true,
        "not_seen_for_amount" => 1,
        "not_seen_for_unit" => "days",
      },
    )

    described_class.handle(DiscourseWorkflows::Nodes::UserSeen::V1, user, previous_seen_at)

    expect(enqueued_trigger_node_ids).to contain_exactly(
      "returning-user-trigger",
      "combined-trigger",
    )
  end

  it "only enqueues user seen workflows matching the selected groups" do
    group = Fabricate(:group)
    other_group = Fabricate(:group)
    seen_at = Time.zone.now
    user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)
    group.add(user)

    create_published_workflow("all-groups-trigger", "trigger:user_seen")
    create_published_workflow(
      "matching-group-trigger",
      "trigger:user_seen",
      configuration: {
        "group_ids" => [group.id.to_s],
      },
    )
    create_published_workflow(
      "group-mismatch-trigger",
      "trigger:user_seen",
      configuration: {
        "group_ids" => [other_group.id.to_s],
      },
    )

    described_class.handle(DiscourseWorkflows::Nodes::UserSeen::V1, user, nil)

    expect(enqueued_trigger_node_ids).to contain_exactly(
      "all-groups-trigger",
      "matching-group-trigger",
    )
  end

  it "does not enqueue post edited workflows for replies by default" do
    create_post(topic: topic)
    create_published_workflow("first-post-only", "trigger:post_edited")

    post = create_post(user: Fabricate(:user, trust_level: TrustLevel[1]), topic: topic)
    described_class.handle(DiscourseWorkflows::Nodes::PostEdited::V1, post, "<p>Cooked</p>")

    expect(enqueued_trigger_node_ids).not_to include("first-post-only")
  end

  it "enqueues user search workflows with the query" do
    create_published_workflow("user-search-trigger", "trigger:user_search")

    Search.execute("workflow query", guardian: Guardian.new(user), search_type: :header)

    job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job["args"].first).to include(
      "trigger_node_id" => "user-search-trigger",
      "trigger_data" => {
        "query" => "workflow query",
      },
    )
  end

  it "only enqueues user added to group workflows matching the group" do
    create_published_workflow(
      "matching-add-trigger",
      "trigger:user_added_to_group",
      configuration: {
        "group_id" => membership_group.id.to_s,
      },
    )
    create_published_workflow(
      "group-mismatch-add-trigger",
      "trigger:user_added_to_group",
      configuration: {
        "group_id" => other_group.id.to_s,
      },
    )

    membership_group.add(user, automatic: true)

    expect(enqueued_trigger_node_ids).to include("matching-add-trigger")
    expect(enqueued_trigger_node_ids).not_to include("group-mismatch-add-trigger")

    trigger_data = trigger_data_for("matching-add-trigger")
    expect(trigger_data).to include(
      "user" => include("id" => user.id, "username" => user.username),
      "group" =>
        include(
          "id" => membership_group.id,
          "name" => membership_group.name,
          "full_name" => membership_group.full_name,
          "automatic" => false,
        ),
      "membership" => {
        "action" => "added",
        "automatic" => true,
      },
    )
  end

  it "only enqueues user removed from group workflows matching the group" do
    Fabricate(:group_user, user: user, group: membership_group)

    create_published_workflow(
      "matching-remove-trigger",
      "trigger:user_removed_from_group",
      configuration: {
        "group_id" => membership_group.id.to_s,
      },
    )
    create_published_workflow(
      "group-mismatch-remove-trigger",
      "trigger:user_removed_from_group",
      configuration: {
        "group_id" => other_group.id.to_s,
      },
    )

    membership_group.remove(user)

    expect(enqueued_trigger_node_ids).to include("matching-remove-trigger")
    expect(enqueued_trigger_node_ids).not_to include("group-mismatch-remove-trigger")

    trigger_data = trigger_data_for("matching-remove-trigger")
    expect(trigger_data).to include(
      "user" => include("id" => user.id, "username" => user.username),
      "group" =>
        include(
          "id" => membership_group.id,
          "name" => membership_group.name,
          "full_name" => membership_group.full_name,
          "automatic" => false,
        ),
      "membership" => {
        "action" => "removed",
        "automatic" => nil,
      },
    )
  end

  it "does not query the dependencies table when no live workflow uses the fired trigger type" do
    create_published_workflow("closed-trigger", "trigger:topic_closed")
    DiscourseWorkflows::WorkflowDependency.active_node_types # warm the cache

    queries =
      track_sql_queries do
        described_class.handle(DiscourseWorkflows::Nodes::TopicCreated::V1, topic)
      end

    dependency_queries =
      queries.select { |sql| sql.include?("discourse_workflows_workflow_dependencies") }
    expect(dependency_queries).to be_empty
    expect(enqueued_trigger_node_ids).to be_empty
  end

  it "does not query workflow tables for a cached user search trigger" do
    create_published_workflow("user-search-trigger", "trigger:user_search")
    DiscourseWorkflows::WorkflowDependency.active_node_types
    DiscourseWorkflows::WorkflowDependency.cached_published_triggers("trigger:user_search")

    queries =
      track_sql_queries do
        Search.execute("workflow query", guardian: Guardian.new(user), search_type: :header)
      end

    workflow_queries =
      queries.select do |sql|
        sql.match?(
          /
            discourse_workflows_workflow_dependencies|
            discourse_workflows_workflow_versions|
            discourse_workflows_workflows
          /x,
        )
      end
    expect(workflow_queries).to be_empty
    expect(enqueued_trigger_node_ids).to contain_exactly("user-search-trigger")
  end

  def create_published_workflow(trigger_node_id, trigger_type, configuration: {})
    graph =
      build_workflow_graph do |g|
        g.node trigger_node_id, trigger_type, configuration: configuration
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
    workflow
  end

  def enqueued_trigger_node_ids
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map do |job|
      job["args"].first["trigger_node_id"]
    end
  end

  def trigger_data_for(trigger_node_id)
    Jobs::DiscourseWorkflows::ExecuteWorkflow
      .jobs
      .find { |job| job["args"].first["trigger_node_id"] == trigger_node_id }
      .dig("args", 0, "trigger_data")
      .deep_stringify_keys
  end
end
