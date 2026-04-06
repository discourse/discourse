# frozen_string_literal: true

RSpec.describe ReviewableAiToolAction do
  fab!(:admin)
  fab!(:ai_agent)
  fab!(:topic)

  let(:bot_user) { Discourse.system_user }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def create_tool_action(tool_name: "close_topic", params: nil)
    params ||= { topic_id: topic.id, closed: true, reason: "Off-topic" }
    AiToolAction.create!(
      tool_name: tool_name,
      tool_parameters: params,
      ai_agent: ai_agent,
      bot_user_id: bot_user.id,
    )
  end

  def create_reviewable(tool_action)
    reviewable =
      described_class.needs_review!(
        target: tool_action,
        created_by: bot_user,
        reviewable_by_moderator: true,
        payload: {
          agent_name: "Test Agent",
          reason: "Off-topic",
        },
      )
    reviewable.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      force_review: true,
    )
    reviewable
  end

  describe "#build_actions" do
    it "has approve and reject actions when pending" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)

      actions = Reviewable::Actions.new(reviewable, Guardian.new(admin), {})
      reviewable.build_actions(actions, Guardian.new(admin), {})

      expect(actions.has?(:approve)).to eq(true)
      expect(actions.has?(:reject)).to eq(true)
    end

    it "returns no actions when not pending" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)
      reviewable.status = Reviewable.statuses[:approved]

      actions = Reviewable::Actions.new(reviewable, Guardian.new(admin), {})
      reviewable.build_actions(actions, Guardian.new(admin), {})

      expect(actions.has?(:approve)).to eq(false)
      expect(actions.has?(:reject)).to eq(false)
    end
  end

  describe "#perform_approve" do
    it "executes the tool and transitions to approved" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)

      result = reviewable.perform(admin, :approve)

      expect(result.success?).to eq(true)
      expect(result.transition_to).to eq(:approved)
      expect(topic.reload.closed).to eq(true)
    end

    it "raises error when target is missing" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)
      tool_action.destroy!
      reviewable.reload

      expect { reviewable.perform(admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises error when tool class is not found" do
      tool_action = create_tool_action(tool_name: "nonexistent_tool")
      reviewable = create_reviewable(tool_action)

      expect { reviewable.perform(admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    end

    it "approves even when tool returns an error result (e.g. stale target)" do
      tool_action = create_tool_action(params: { topic_id: -999, closed: true, reason: "test" })
      reviewable = create_reviewable(tool_action)

      result = reviewable.perform(admin, :approve)

      expect(result.success?).to eq(true)
      expect(result.transition_to).to eq(:approved)
    end
  end

  describe "#perform_reject" do
    it "transitions to rejected without executing the tool" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)

      result = reviewable.perform(admin, :reject)

      expect(result.success?).to eq(true)
      expect(result.transition_to).to eq(:rejected)
      expect(topic.reload.closed).to eq(false)
    end
  end
end
