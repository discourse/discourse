# frozen_string_literal: true

RSpec.describe "Workflow: post destroyed -> delete post" do
  fab!(:admin)
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:source_post) { create_post(user: author, raw: "Source post") }
  fab!(:mirror_post) { create_post(user: author, raw: "Mirror post") }

  before do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_destroyed"
        g.node "action-1",
               "action:post",
               configuration: {
                 "operation" => "delete",
                 "post_id" => mirror_post.id.to_s,
                 "actor_username" => "system",
               }
        g.chain "trigger-1", "action-1"
      end

    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      published: true,
      name: "Delete the mirror post",
      **graph,
    )
  end

  it "deletes the mirror post without enqueueing another workflow run" do
    PostDestroyer.new(admin, source_post).destroy

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

    job_args = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first.symbolize_keys

    expect { Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_args) }.to change {
      mirror_post.reload.deleted_at
    }.from(nil)

    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
  end
end
