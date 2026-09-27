# frozen_string_literal: true

RSpec.describe "Workflow status event triggers" do
  fab!(:admin)
  fab!(:user)
  fab!(:topic, :topic_with_op)

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  it "dispatches automatic topic closes to the existing and status triggers once" do
    create_workflow("closed", "trigger:topic_closed")
    create_workflow("status", "trigger:topic_status_changed", "statuses" => ["closed"])
    create_workflow("reopened", "trigger:topic_reopened", "statuses" => ["closed"])

    2.times { TopicStatusUpdater.new(topic, admin).update!("autoclosed", true) }
    2.times { TopicStatusUpdater.new(topic, admin).update!("closed", false) }

    expect(enqueued_jobs.map { |job| job["trigger_node_id"] }).to contain_exactly(
      "closed",
      "status",
      "reopened",
    )
    expect(
      enqueued_jobs.find { |job| job["trigger_node_id"] == "status" }["trigger_data"],
    ).to include("status" => "closed", "enabled" => true, "change" => "closed")
    expect(
      enqueued_jobs.find { |job| job["trigger_node_id"] == "reopened" }["trigger_data"],
    ).to include("status" => "closed", "enabled" => false, "change" => "reopened")
  end

  it "dispatches unpinning according to the previous pin scope" do
    topic.update_status("pinned_globally", true, admin)
    create_workflow("global", "trigger:topic_unpinned_globally", "statuses" => ["unpinned"])
    create_workflow("category", "trigger:topic_unpinned", "statuses" => ["unpinned_globally"])

    topic.update_status("pinned", false, admin)
    topic.update_status("pinned", true, admin)
    topic.update_status("pinned_globally", false, admin)

    expect(enqueued_jobs.map { |job| job["trigger_node_id"] }).to eq(%w[global category])
    expect(enqueued_jobs.first["trigger_data"]).to include(
      "status" => "pinned_globally",
      "enabled" => false,
      "change" => "unpinned_globally",
    )
    expect(enqueued_jobs.last["trigger_data"]).to include(
      "status" => "pinned",
      "enabled" => false,
      "change" => "unpinned",
    )
  end

  it "dispatches rejected reviewables to the matching outcome trigger" do
    reviewable = Fabricate(:reviewable_flagged_post)
    create_workflow("rejected", "trigger:reviewable_status_changed", "statuses" => ["rejected"])
    create_workflow("fixed-rejected", "trigger:reviewable_rejected", "statuses" => ["approved"])
    create_workflow("approved", "trigger:reviewable_approved")

    reviewable.transition_to(:rejected, admin)

    expect(enqueued_jobs.map { |job| job["trigger_node_id"] }).to contain_exactly(
      "rejected",
      "fixed-rejected",
    )
    enqueued_jobs.each do |job|
      expect(job.dig("trigger_data", "reviewable")).to include(
        "id" => reviewable.id,
        "status" => "rejected",
      )
      expect(job["trigger_data"]).to match_node_output_schema(
        DiscourseWorkflows::Nodes::ReviewableStatusChanged::V1,
      )
    end
  end

  it "dispatches promotions with both trust levels and the execution user" do
    user.update!(trust_level: TrustLevel.levels[:basic])
    create_workflow(
      "promoted",
      "trigger:user_trust_level_changed",
      "old_trust_levels" => [TrustLevel.levels[:basic].to_s],
      "new_trust_levels" => [TrustLevel.levels[:member].to_s],
    )

    Promotion.new(user).change_trust_level!(TrustLevel.levels[:member])

    expect(enqueued_jobs.size).to eq(1)
    expect(enqueued_jobs.first["user_id"]).to eq(user.id)
    expect(enqueued_jobs.first["trigger_data"]).to include(
      "old_trust_level" => TrustLevel.levels[:basic],
      "new_trust_level" => TrustLevel.levels[:member],
    )
    expect(enqueued_jobs.first["trigger_data"]).to match_node_output_schema(
      DiscourseWorkflows::Nodes::UserTrustLevelChanged::V1,
    )
  end

  it "dispatches first login without dispatching later logins" do
    user.update!(last_seen_at: nil)
    create_workflow("first-login", "trigger:user_first_logged_in")

    user.logged_in
    user.update!(last_seen_at: Time.current)
    user.logged_in

    expect(enqueued_jobs.size).to eq(1)
    expect(enqueued_jobs.first["user_id"]).to eq(user.id)
    expect(enqueued_jobs.first.dig("trigger_data", "user", "id")).to eq(user.id)
    expect(enqueued_jobs.first["trigger_data"]).to match_node_output_schema(
      DiscourseWorkflows::Nodes::UserFirstLoggedIn::V1,
    )
  end

  def create_workflow(trigger_id, trigger_type, configuration = {})
    graph =
      build_workflow_graph do |graph_builder|
        graph_builder.node trigger_id, trigger_type, configuration: configuration
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  def enqueued_jobs
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first }
  end
end
