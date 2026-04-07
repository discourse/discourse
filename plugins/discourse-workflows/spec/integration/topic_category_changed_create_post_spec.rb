# frozen_string_literal: true

RSpec.describe "Workflow: topic category changed -> create post" do
  fab!(:admin)
  fab!(:category)
  fab!(:target_category, :category)
  fab!(:topic) { Fabricate(:topic, category: category) }

  before do
    SiteSetting.discourse_workflows_enabled = true

    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      enabled: true,
      name: "Notify on category change",
      nodes: [
        {
          "id" => "trigger-1",
          "type" => "trigger:topic_category_changed",
          "type_version" => "1.0",
          "name" => "Category Changed",
          "position" => {
            "x" => 0,
            "y" => 0,
          },
          "position_index" => 0,
          "configuration" => {
          },
        },
        {
          "id" => "action-1",
          "type" => "action:create_post",
          "type_version" => "1.0",
          "name" => "Create Post",
          "position" => {
            "x" => 200,
            "y" => 0,
          },
          "position_index" => 1,
          "configuration" => {
            "topic_id" => "={{ trigger.topic.id }}",
            "raw" =>
              "=Category changed from {{ trigger.old_category_id }} to {{ trigger.topic.category_id }}",
          },
        },
      ],
      connections: [
        {
          "source_node_id" => "trigger-1",
          "target_node_id" => "action-1",
          "source_output" => "main",
        },
      ],
    )
  end

  it "creates a post when topic category changes" do
    topic.change_category_to_id(target_category.id)

    job_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job_data).to be_present

    trigger_data = job_data["args"].first["trigger_data"]
    expect(trigger_data["topic"]).to include("id" => topic.id, "category_id" => target_category.id)
    expect(trigger_data).to include("old_category_id" => category.id)

    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_data["args"].first.symbolize_keys)

    post = topic.reload.posts.where.not(post_type: Post.types[:small_action]).last
    expect(post.raw).to include(category.id.to_s)
    expect(post.raw).to include(target_category.id.to_s)

    execution = DiscourseWorkflows::Execution.last
    expect(execution.status).to eq("success")
  end

  it "does not trigger when category stays the same" do
    topic.change_category_to_id(category.id)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_data"]&.dig("topic", "id") == topic.id
      end
    expect(jobs).to be_empty
  end

  it "does not trigger when the workflow is disabled" do
    DiscourseWorkflows::Workflow.update_all(enabled: false)

    topic.change_category_to_id(target_category.id)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_data"]&.dig("topic", "id") == topic.id
      end
    expect(jobs).to be_empty
  end
end
