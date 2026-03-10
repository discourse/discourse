# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::EditPost do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:post) { Fabricate(:post, raw: "Original content") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Agents::BotContext.new }

  it "edits the post content" do
    result = tool(post_id: post.id, raw: "Updated content", edit_reason: "Fixing typo").invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.raw).to eq("Updated content")
    expect(post.edit_reason).to be_nil
  end

  it "sets a public edit reason when public_edit_reason is true" do
    result =
      tool(
        post_id: post.id,
        raw: "Updated content",
        edit_reason: "Fixing typo",
        public_edit_reason: true,
      ).invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.edit_reason).to eq("Fixing typo")
  end

  it "edits the topic title via the first post" do
    first_post = post.topic.first_post

    result =
      tool(post_id: first_post.id, title: "New Topic Title", edit_reason: "Better title").invoke

    expect(result[:status]).to eq("success")
    expect(first_post.topic.reload.title).to eq("New Topic Title")
  end

  it "returns an error when post is not found" do
    result = tool(post_id: -1, raw: "Content", edit_reason: "Reason").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when neither raw nor title is provided" do
    result = tool(post_id: post.id, edit_reason: "No changes").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when edit_reason is blank" do
    result = tool(post_id: post.id, raw: "Content", edit_reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    other_post = Fabricate(:post)
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { post_id: other_post.id, raw: "New content", edit_reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
