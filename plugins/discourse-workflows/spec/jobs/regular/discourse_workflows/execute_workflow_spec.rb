# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ExecuteWorkflow do
  fab!(:user)
  fab!(:workflow) do
    graph = build_workflow_graph { |builder| builder.node "trigger-1", "trigger:post_button" }
    Fabricate(:discourse_workflows_workflow, published: true, **graph)
  end

  let(:request_id) { SecureRandom.uuid }
  let(:channel) { "/discourse-workflows/post-button/#{user.id}/#{request_id}" }

  def execute_job(args, jid: SecureRandom.hex(12))
    job = described_class.new
    job.jid = jid
    job.execute(args)
  end
  let(:args) do
    {
      workflow_id: workflow.id,
      workflow_version_id: workflow.active_version_id,
      trigger_node_id: "trigger-1",
      user_id: user.id,
      post_button_feedback: {
        client_id: "clicking-tab",
        request_id:,
      },
    }
  end

  it "publishes success and rate limiting to the clicking user and tab" do
    SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1
    RateLimiter.enable

    messages = MessageBus.track_publish(channel) { 2.times { execute_job(args) } }

    expect(workflow.executions.pluck(:status)).to contain_exactly("success", "rate_limited")
    expect(messages).to contain_exactly(
      have_attributes(
        data: {
          status: "success",
        },
        user_ids: [user.id],
        client_ids: ["clicking-tab"],
      ),
      have_attributes(
        data: {
          status: "rate_limited",
        },
        user_ids: [user.id],
        client_ids: ["clicking-tab"],
      ),
    )
  ensure
    RateLimiter.disable
  end

  it "publishes a terminal error without exposing the underlying error" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:post_button"
        builder.node "code-1",
                     "action:code",
                     configuration: {
                       "code" => "throw new Error('private failure details');",
                     }
        builder.chain "trigger-1", "code-1"
      end
    failing_workflow = Fabricate(:discourse_workflows_workflow, published: true, **graph)

    messages =
      MessageBus.track_publish(channel) do
        execute_job(
          args.merge(
            workflow_id: failing_workflow.id,
            workflow_version_id: failing_workflow.active_version_id,
          ),
        )
      end

    expect(failing_workflow.executions.sole).to be_error
    expect(messages).to contain_exactly(
      have_attributes(data: { status: "error" }, user_ids: [user.id], client_ids: ["clicking-tab"]),
    )
  end

  it "preserves feedback across a duplicate delivery during approval and publishes upon completion" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger-1", "trigger:post_button"
        builder.node "modal-1",
                     "action:modal",
                     configuration: {
                       "title" => "Apply?",
                       "buttons" => {
                         "values" => [{ "label" => "Apply", "value" => "apply" }],
                       },
                     }
        builder.chain "trigger-1", "modal-1"
      end
    interactive = Fabricate(:discourse_workflows_workflow, published: true, **graph)
    jid = SecureRandom.hex(12)
    interactive_args =
      args.merge(workflow_id: interactive.id, workflow_version_id: interactive.active_version_id)
    messages =
      MessageBus.track_publish(channel) do
        execute_job(interactive_args, jid:)
        SiteSetting.enable_discourse_workflows = false
        execute_job(interactive_args, jid:)
        SiteSetting.enable_discourse_workflows = true
      end
    execution = interactive.executions.sole
    expect(execution).to be_waiting
    expect(messages).to be_empty

    action_id =
      DiscourseWorkflows::InteractiveResume.action_id(
        execution_id: execution.id,
        resume_token: execution.resume_token,
        action: "apply",
        target_user_id: user.id,
      )
    messages =
      MessageBus.track_publish(channel) do
        DiscourseWorkflows::Modal::Respond.call(guardian: user.guardian, params: { action_id: })
        execute_job(interactive_args, jid:)
      end
    expect(execution.reload).to be_success
    expect(messages).to contain_exactly(
      have_attributes(
        data: {
          status: "success",
        },
        user_ids: [user.id],
        client_ids: ["clicking-tab"],
      ),
    )
  end

  it "does not publish post-button feedback for other queued triggers" do
    messages =
      MessageBus.track_publish(channel) do
        execute_job(args.except(:post_button_feedback).merge(workflow_id: -1))
      end

    expect(messages).to be_empty
  end
end
