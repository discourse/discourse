# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::EventListener do
  fab!(:user)
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:tag) { Fabricate(:tag, name: "matched") }

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
    SiteSetting.discourse_workflows_enabled = false

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

  it "does not enqueue post edited workflows for replies by default" do
    create_post(topic: topic)
    create_published_workflow("first-post-only", "trigger:post_edited")

    post = create_post(user: Fabricate(:user, trust_level: TrustLevel[1]), topic: topic)
    described_class.handle(DiscourseWorkflows::Nodes::PostEdited::V1, post, "<p>Cooked</p>")

    expect(enqueued_trigger_node_ids).not_to include("first-post-only")
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
end
