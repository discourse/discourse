# frozen_string_literal: true

RSpec.describe "Workflow: user created -> flag user" do
  fab!(:admin)

  before do
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:user_created"
        g.node "action-1",
               "action:flag_user",
               configuration: {
                 "username" => "={{ $trigger.user.username }}",
                 "reason" => "Automated signup screening",
               }
        g.chain "trigger-1", "action-1"
      end

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      published: true,
      name: "Flag <b>spam</b> signups",
      **graph,
    )
  end

  it "queues the new signup for moderator review", :aggregate_failures do
    user = Fabricate(:user)

    job_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    expect(job_data).to be_present

    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_data["args"].first.symbolize_keys)

    reviewable = ReviewableUser.pending.find_by(target: user)
    expect(reviewable).to be_present
    expect(reviewable.reviewable_scores.last.reason).to eq("workflow_flagged_user")

    expect(reviewable.reviewable_notes.last.content).to eq(
      "#{
        I18n.t(
          "discourse_workflows.flag_user.flagged_by_workflow",
          workflow_name: "Flag <b>spam</b> signups",
        )
      }\n\nAutomated signup screening",
    )

    execution = DiscourseWorkflows::Execution.last
    expect(execution.status).to eq("success")
  end
end
