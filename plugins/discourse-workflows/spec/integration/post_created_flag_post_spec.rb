# frozen_string_literal: true

RSpec.describe "Workflow: post created -> flag post" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic_owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: topic_owner, raw: "First post") }
  fab!(:topic) { first_post.topic }

  before do
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created"
        g.node "action-1",
               "action:flag_post",
               configuration: {
                 "post_id" => "={{ $trigger.post.id }}",
                 "flag_type" => "spam",
                 "reason" => "Automated spam detection",
               }
        g.chain "trigger-1", "action-1"
      end

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      published: true,
      name: "Flag <b>spam</b> replies",
      **graph,
    )
  end

  it "flags a newly created reply as spam and hides it", :aggregate_failures do
    reply = PostCreator.create!(user, topic_id: topic.id, raw: "This is a spammy reply")

    job_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job_data).to be_present

    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_data["args"].first.symbolize_keys)

    reviewable = ReviewableFlaggedPost.pending.find_by(target: reply)
    expect(reviewable).to be_present
    expect(reviewable.reviewable_scores.last.reason).to eq(
      "#{
        I18n.t(
          "discourse_workflows.flag_post.flagged_by_workflow",
          workflow_name: "Flag &lt;b&gt;spam&lt;/b&gt; replies",
        )
      }<br>Automated spam detection",
    )
    expect(reply.reload.hidden?).to eq(true)
    expect(topic.reload.visible).to eq(true)

    execution = DiscourseWorkflows::Execution.last
    expect(execution.status).to eq("success")
  end
end
