# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::PerformReviewableAction do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:admin)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, user: admin, **kwargs)
    params ||= kwargs
    ctx = DiscourseAi::Agents::BotContext.new(user: user)
    described_class.new(params, bot_user: bot_user, llm: llm, context: ctx)
  end

  it "returns an error when user cannot see review queue" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    result =
      tool(
        { reviewable_id: 1, action_id: "agree_and_keep", reason: "test" },
        user: regular_user,
      ).invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end

  it "returns an error when reason is blank" do
    result = tool(reviewable_id: 1, action_id: "agree_and_keep", reason: " ").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("reason")
  end

  it "returns an error when reviewable is not found" do
    result = tool(reviewable_id: -1, action_id: "agree_and_keep", reason: "test").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not found")
  end

  context "with a flagged post" do
    fab!(:post)
    fab!(:flagged_reviewable) do
      ReviewableFlaggedPost.needs_review!(
        target: post,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
      )
    end

    it "returns an error for invalid action" do
      result =
        tool(
          reviewable_id: flagged_reviewable.id,
          action_id: "nonexistent_action",
          reason: "test",
        ).invoke

      expect(result[:status]).to eq("error")
      expect(result[:error]).to include("Invalid action")
    end

    it "successfully performs agree_and_keep" do
      result =
        tool(
          reviewable_id: flagged_reviewable.id,
          action_id: "agree_and_keep",
          reason: "Confirmed violation",
        ).invoke

      expect(result[:status]).to eq("success")
      expect(flagged_reviewable.reload.status).to eq("approved")
    end

    it "persists the reason as a reviewable note" do
      tool(
        reviewable_id: flagged_reviewable.id,
        action_id: "agree_and_keep",
        reason: "AI determined this violates policy",
      ).invoke

      note = flagged_reviewable.reviewable_notes.last
      expect(note).to be_present
      expect(note.content).to eq("AI determined this violates policy")
    end

    it "successfully performs agree_and_hide" do
      PostActionCreator.inappropriate(Fabricate(:user, refresh_auto_groups: true), post)

      result =
        tool(
          reviewable_id: flagged_reviewable.id,
          action_id: "agree_and_hide",
          reason: "Hiding inappropriate content",
        ).invoke

      expect(result[:status]).to eq("success")
      expect(flagged_reviewable.reload.status).to eq("approved")
      expect(post.reload.hidden).to eq(true)
    end

    it "successfully performs disagree" do
      result =
        tool(
          reviewable_id: flagged_reviewable.id,
          action_id: "disagree",
          reason: "Post is fine",
        ).invoke

      expect(result[:status]).to eq("success")
      expect(flagged_reviewable.reload.status).to eq("rejected")
    end

    it "successfully performs ignore" do
      result =
        tool(
          reviewable_id: flagged_reviewable.id,
          action_id: "ignore_and_do_nothing",
          reason: "Not sure, deferring",
        ).invoke

      expect(result[:status]).to eq("success")
      expect(flagged_reviewable.reload.status).to eq("ignored")
    end
  end

  context "with a queued post" do
    fab!(:queued_reviewable) do
      Fabricate(
        :reviewable_queued_post_topic,
        created_by: Fabricate(:user),
        status: Reviewable.statuses[:pending],
      )
    end

    it "successfully approves a queued post" do
      result =
        tool(
          reviewable_id: queued_reviewable.id,
          action_id: "approve_post",
          reason: "Looks good",
        ).invoke

      expect(result[:status]).to eq("success")
      expect(queued_reviewable.reload.status).to eq("approved")
    end
  end
end
