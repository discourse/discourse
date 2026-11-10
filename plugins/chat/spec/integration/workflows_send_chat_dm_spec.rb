# frozen_string_literal: true

RSpec.describe "Workflow: send chat direct message to a user" do
  fab!(:admin)

  def publish_workflow(trigger_type, trigger_configuration = {})
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", trigger_type, configuration: trigger_configuration
        g.node "action-1",
               "action:send_chat_message",
               configuration: {
                 "target" => "user",
                 "target_usernames" => "={{ $trigger.user.username }}",
                 "message" => "=Welcome {{ $trigger.user.username }}!",
               }
        g.chain "trigger-1", "action-1"
      end

    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  def run_last_enqueued_workflow
    job_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
    Jobs::DiscourseWorkflows::ExecuteWorkflow.new.execute(job_data["args"].first.symbolize_keys)
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.enable_discourse_workflows = true
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear
  end

  it "sends a direct message from the system user once a user reaches trust level 1" do
    publish_workflow("trigger:user_trust_level_changed", "new_trust_levels" => [TrustLevel[1].to_s])
    user = Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true)

    Promotion.new(user).change_trust_level!(TrustLevel[1])
    run_last_enqueued_workflow

    execution = DiscourseWorkflows::Execution.last
    expect(execution.status).to eq("success")

    message = Chat::Message.last
    expect(message).to have_attributes(
      user_id: Discourse.system_user.id,
      message: "Welcome #{user.username}!",
    )
    expect(message.chat_channel.chatable.users).to contain_exactly(Discourse.system_user, user)
  end
end
