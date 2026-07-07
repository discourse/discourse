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

  def create_tool_action(tool_name: "close_topic", params: nil, post_id: nil)
    params ||= { topic_id: topic.id, closed: true, reason: "Off-topic" }
    AiToolAction.create!(
      tool_name: tool_name,
      tool_parameters: params,
      ai_agent: ai_agent,
      bot_user_id: bot_user.id,
      post_id: post_id,
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

  describe "#created_new!" do
    fab!(:private_category_group, :group)
    fab!(:private_category) { Fabricate(:private_category, group: private_category_group) }
    fab!(:private_topic) { Fabricate(:topic, category: private_category) }
    fab!(:private_post) { Fabricate(:post, topic: private_topic) }

    it "scopes the reviewable to the target post's topic and category" do
      tool_action = create_tool_action(post_id: private_post.id)
      reviewable = create_reviewable(tool_action)

      expect(reviewable.topic).to eq(private_topic)
      expect(reviewable.category).to eq(private_category)
    end

    it "leaves topic and category blank when the target action has no post" do
      tool_action = create_tool_action(post_id: nil)
      reviewable = create_reviewable(tool_action)

      expect(reviewable.topic).to be_nil
      expect(reviewable.category).to be_nil
    end
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

    it "returns no actions for a user who cannot see the review queue" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)
      regular_user = Fabricate(:user)

      actions = Reviewable::Actions.new(reviewable, Guardian.new(regular_user), {})
      reviewable.build_actions(actions, Guardian.new(regular_user), {})

      expect(actions.has?(:approve)).to eq(false)
      expect(actions.has?(:reject)).to eq(false)
    end

    it "returns actions for a category group moderator scoped to the reviewable's category" do
      category = Fabricate(:category)
      post = Fabricate(:post, topic: Fabricate(:topic, category: category))
      tool_action = create_tool_action(post_id: post.id)
      reviewable = create_reviewable(tool_action)

      SiteSetting.enable_category_group_moderation = true
      group = Fabricate(:group)
      Fabricate(:category_moderation_group, category:, group:)
      group_moderator = Fabricate(:user, groups: [group])

      actions = Reviewable::Actions.new(reviewable, Guardian.new(group_moderator), {})
      reviewable.build_actions(actions, Guardian.new(group_moderator), {})

      expect(actions.has?(:approve)).to eq(true)
      expect(actions.has?(:reject)).to eq(true)
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

    it "raises and stays pending when the tool returns an error result (e.g. stale target)" do
      tool_action = create_tool_action(params: { topic_id: -999, closed: true, reason: "test" })
      reviewable = create_reviewable(tool_action)

      expect { reviewable.perform(admin, :approve) }.to raise_error(Discourse::InvalidAccess)
      expect(reviewable.reload).to be_pending
    end

    it "raises and stays pending when the approver lacks permission at replay time" do
      target_user = Fabricate(:user)
      tool_action =
        create_tool_action(
          tool_name: "suspend_user",
          params: {
            username: target_user.username,
            duration_days: 7,
            reason: "Spam",
          },
        )
      reviewable = create_reviewable(tool_action)
      moderator = Fabricate(:moderator)

      # A plain moderator cannot suspend an admin, so the replayed tool fails.
      target_user.update!(admin: true)

      expect { reviewable.perform(moderator, :approve) }.to raise_error(Discourse::InvalidAccess)
      expect(reviewable.reload).to be_pending
      expect(target_user.reload.suspended?).to eq(false)
    end

    it "raises error when performed_by is a bot account" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)

      expect { reviewable.perform(bot_user, :approve) }.to raise_error(Discourse::InvalidAccess)
      expect(topic.reload.closed).to eq(false)
    end

    it "attributes the action to the approving moderator for tools that opt into attribute_to_approver?" do
      target_user = Fabricate(:user)
      tool_action =
        create_tool_action(
          tool_name: "suspend_user",
          params: {
            username: target_user.username,
            duration_days: 7,
            reason: "Spam",
          },
        )
      reviewable = create_reviewable(tool_action)

      result = reviewable.perform(admin, :approve)

      expect(result.success?).to eq(true)
      expect(target_user.reload.suspended?).to eq(true)

      suspend_history = UserHistory.where(action: UserHistory.actions[:suspend_user]).last
      expect(suspend_history.acting_user_id).to eq(admin.id)
      expect(suspend_history.target_user_id).to eq(target_user.id)
      expect(suspend_history.reviewable_id).to eq(reviewable.id)
    end

    it "attributes a silence_user approval to the approving moderator" do
      target_user = Fabricate(:user)
      tool_action =
        create_tool_action(
          tool_name: "silence_user",
          params: {
            username: target_user.username,
            duration_days: 7,
            reason: "Spam",
          },
        )
      reviewable = create_reviewable(tool_action)

      result = reviewable.perform(admin, :approve)

      expect(result.success?).to eq(true)
      expect(target_user.reload.silenced?).to eq(true)

      silence_history = UserHistory.where(action: UserHistory.actions[:silence_user]).last
      expect(silence_history.acting_user_id).to eq(admin.id)
      expect(silence_history.target_user_id).to eq(target_user.id)
      expect(silence_history.reviewable_id).to eq(reviewable.id)
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

    it "raises error when performed_by is a bot account" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)

      expect { reviewable.perform(bot_user, :reject) }.to raise_error(Discourse::InvalidAccess)
    end
  end
end
