# frozen_string_literal: true

RSpec.describe "Workflow: topic category changed -> create post" do
  fab!(:admin)
  fab!(:category)
  fab!(:target_category, :category)
  fab!(:topic) { Fabricate(:topic, category: category) }

  before do
    SiteSetting.discourse_workflows_enabled = true

    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(
      DiscourseWorkflows::Triggers::TopicCategoryChanged::V1,
    )
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::CreatePost::V1)

    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        enabled: true,
        name: "Notify on category change",
      )

    trigger_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:topic_category_changed",
        name: "Category Changed",
        position_index: 0,
      )

    action_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:create_post",
        name: "Create Post",
        position_index: 1,
        configuration: {
          "topic_id" => "={{ trigger.topic_id }}",
          "raw" =>
            "=Category changed from {{ trigger.old_category_id }} to {{ trigger.category_id }}",
        },
      )

    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: action_node,
    )
  end

  after { DiscourseWorkflows::Registry.reset! }

  it "creates a post when topic category changes" do
    topic.change_category_to_id(target_category.id)

    job_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job_data).to be_present

    trigger_data = job_data["args"].first["trigger_data"]
    expect(trigger_data["topic_id"]).to eq(topic.id)
    expect(trigger_data["old_category_id"]).to eq(category.id)
    expect(trigger_data["category_id"]).to eq(target_category.id)

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
        j["args"].first["trigger_data"]&.dig("topic_id") == topic.id
      end
    expect(jobs).to be_empty
  end

  it "does not trigger when the workflow is disabled" do
    DiscourseWorkflows::Workflow.update_all(enabled: false)

    topic.change_category_to_id(target_category.id)

    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_data"]&.dig("topic_id") == topic.id
      end
    expect(jobs).to be_empty
  end
end
