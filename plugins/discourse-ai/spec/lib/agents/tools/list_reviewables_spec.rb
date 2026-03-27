# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ListReviewables do
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
    result = tool({}, user: regular_user).invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end

  it "returns empty result when no reviewables exist" do
    result = tool({}).invoke

    expect(result[:status]).to eq("success")
    expect(result[:reviewables]).to eq([])
  end

  context "with pending reviewables" do
    fab!(:post)
    fab!(:flagged_reviewable) do
      ReviewableFlaggedPost.needs_review!(
        target: post,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
      )
    end

    it "lists pending reviewables" do
      result = tool({}).invoke

      expect(result[:status]).to eq("success")
      expect(result[:reviewables].size).to eq(1)

      item = result[:reviewables].first
      expect(item[:id]).to eq(flagged_reviewable.id)
      expect(item[:type]).to eq("ReviewableFlaggedPost")
      expect(item[:status]).to eq("pending")
      expect(item[:post_id]).to eq(post.id)
    end

    it "filters by type" do
      result = tool(type: "ReviewableUser").invoke

      expect(result[:status]).to eq("success")
      expect(result[:reviewables]).to be_empty
    end

    it "returns error for invalid type" do
      result = tool(type: "InvalidType").invoke

      expect(result[:status]).to eq("error")
      expect(result[:error]).to include("Invalid")
    end

    it "returns error for invalid status" do
      result = tool(status: "bogus").invoke

      expect(result[:status]).to eq("error")
      expect(result[:error]).to include("Invalid status")
    end

    it "filters by min_hours_old" do
      flagged_reviewable.update!(created_at: 5.hours.ago)

      result = tool(min_hours_old: 3).invoke
      expect(result[:reviewables].size).to eq(1)

      result = tool(min_hours_old: 10).invoke
      expect(result[:reviewables]).to be_empty
    end

    it "filters by max_hours_old" do
      flagged_reviewable.update!(created_at: 5.hours.ago)

      result = tool(max_hours_old: 10).invoke
      expect(result[:reviewables].size).to eq(1)

      result = tool(max_hours_old: 3).invoke
      expect(result[:reviewables]).to be_empty
    end

    it "includes available actions" do
      result = tool({}).invoke

      item = result[:reviewables].first
      expect(item[:available_actions]).to be_present
      expect(item[:available_actions]).to include("agree_and_hide")
    end

    it "includes score details" do
      flagged_reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        reason: "test reason",
        force_review: true,
      )

      result = tool({}).invoke

      item = result[:reviewables].first
      expect(item[:scores]).to be_present
      expect(item[:scores].first[:user]).to eq("system")
    end
  end
end
