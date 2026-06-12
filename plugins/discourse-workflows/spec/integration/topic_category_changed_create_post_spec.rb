# frozen_string_literal: true

RSpec.describe "Workflow: topic category changed -> create post" do
  fab!(:admin)
  fab!(:category)
  fab!(:target_category, :category)
  fab!(:topic) { Fabricate(:topic, category: category) }

  before do
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:topic_category_changed"
        g.node "action-1",
               "action:post",
               configuration: {
                 "operation" => "create",
                 "topic_id" => "={{ $trigger.topic.id }}",
                 "raw" =>
                   "=Category changed from {{ $trigger.old_category_id }} to {{ $trigger.topic.category_id }}",
               }
        g.chain "trigger-1", "action-1"
      end

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      published: true,
      name: "Notify on category change",
      **graph,
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

  def expect_no_workflow_jobs_for(topic)
    jobs =
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.select do |j|
        j["args"].first["trigger_data"]&.dig("topic", "id") == topic.id
      end
    expect(jobs).to be_empty
  end

  it "does not trigger when category stays the same" do
    topic.change_category_to_id(category.id)
    expect_no_workflow_jobs_for(topic)
  end

  it "does not trigger when the workflow is unpublished" do
    DiscourseWorkflows::Workflow.find_each { |workflow| unpublish_workflow!(workflow) }
    topic.change_category_to_id(target_category.id)
    expect_no_workflow_jobs_for(topic)
  end
end
