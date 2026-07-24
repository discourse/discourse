# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::InteractiveResume do
  fab!(:user)
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "wait-1", "flow:wait", configuration: { "resume" => "webhook" }
        g.chain "trigger-1", "wait-1"
      end
    Fabricate(:discourse_workflows_workflow, created_by: user, **graph).tap do |wf|
      publish_workflow!(wf)
    end
  end

  let(:execution) { DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run }
  let(:action_id) do
    DiscourseWorkflows::InteractiveResume.action_id(
      execution_id: execution.id,
      resume_token: execution.resume_token,
      action: "resume",
    )
  end

  describe ".action_id" do
    it "returns an opaque signed action id" do
      payload = described_class.action_payload(action_id)

      expect(payload).to include("execution_id" => execution.id, "action" => "resume")
      expect(action_id).not_to include(execution.resume_token)
    end
  end

  describe ".action_id?" do
    it "returns true for a valid waiting execution action" do
      expect(
        described_class.action_id?(
          action_id,
          expected_node_type: "flow:wait",
          allowed_actions: %w[resume],
        ),
      ).to eq(true)
    end

    it "returns false when the action is not allowed" do
      expect(
        described_class.action_id?(
          action_id,
          expected_node_type: "flow:wait",
          allowed_actions: %w[approve deny],
        ),
      ).to eq(false)
    end
  end

  describe ".from_action_id" do
    it "returns a resumable request for a valid waiting execution action" do
      request =
        described_class.from_action_id(
          action_id,
          expected_node_type: "flow:wait",
          allowed_actions: %w[resume],
        )

      expect(request.action).to eq("resume")
    end

    it "returns nil when the waiting node type does not match" do
      expect(
        described_class.from_action_id(
          action_id,
          expected_node_type: "action:chat_approval",
          allowed_actions: %w[resume],
        ),
      ).to be_nil
    end

    it "returns nil when the bound target user id in the token is altered" do
      bound_action_id =
        DiscourseWorkflows::InteractiveResume.action_id(
          execution_id: execution.id,
          resume_token: execution.resume_token,
          action: "resume",
          target_user_id: user.id,
        )
      _execution_id, _target_user_id, action, signature = bound_action_id.split(":", 4)
      tampered = [execution.id, user.id + 1, action, signature].join(":")

      expect(
        described_class.from_action_id(
          tampered,
          expected_node_type: "flow:wait",
          allowed_actions: %w[resume],
        ),
      ).to be_nil
    end
  end

  describe DiscourseWorkflows::InteractiveResume::Request do
    it "claims the execution atomically" do
      request =
        DiscourseWorkflows::InteractiveResume.from_action_id(
          action_id,
          expected_node_type: "flow:wait",
          allowed_actions: %w[resume],
        )

      claimed_request = request.claim

      expect(claimed_request.action).to eq("resume")
      expect(execution.reload.status).to eq("running")
      expect(request.claim).to be_nil
    end
  end

  describe DiscourseWorkflows::InteractiveResume::ClaimedRequest do
    it "resumes the claimed execution" do
      request =
        DiscourseWorkflows::InteractiveResume.from_action_id(
          action_id,
          expected_node_type: "flow:wait",
          allowed_actions: %w[resume],
        )
      claimed_request = request.claim

      claimed_request.resume!([{ "json" => { "approved" => true } }])

      expect(execution.reload.status).to eq("success")
    end
  end
end
