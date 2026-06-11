# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::AddReviewableNote do
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
    result = tool({ reviewable_id: 1, note: "test" }, user: regular_user).invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end

  it "returns an error when note is blank" do
    result = tool(reviewable_id: 1, note: " ").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("note")
  end

  it "returns an error when reviewable is not found" do
    result = tool(reviewable_id: -1, note: "test").invoke

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

    it "adds a note to the reviewable without changing its status" do
      result = tool(reviewable_id: flagged_reviewable.id, note: "This looks like spam to me").invoke

      expect(result[:status]).to eq("success")

      note = flagged_reviewable.reload.reviewable_notes.last
      expect(note).to be_present
      expect(note.content).to eq("This looks like spam to me")
      expect(note.user).to be_present
      expect(result[:note_id]).to eq(note.id)
      expect(flagged_reviewable.status).to eq("pending")
    end
  end
end
