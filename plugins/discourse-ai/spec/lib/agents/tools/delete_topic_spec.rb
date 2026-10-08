# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::DeleteTopic do
  fab!(:llm_model)
  fab!(:bot_user, :admin)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:post)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Agents::BotContext.new }

  it "previews both directions with the topic title and explicit states" do
    target = post.topic
    target.update!(deleted_at: nil)
    action_tool = tool(topic_id: target.id, deleted: true, reason: "Testing")
    title = Nokogiri::HTML5.fragment(Chat::Message.cook(action_tool.approval_title))
    expect(title.at_css("a").text).to eq(target.title)
    expect(title.at_css("a")["href"]).to eq(target.url)
    expect(action_tool.approval_changes).to eq(
      [{ label: "Changing status:", before: "Active", after: "Deleted" }],
    )
    expect(action_tool.approval_parameters).to be_empty
    expect(target.reload.deleted_at).to eq(nil)

    target.update!(deleted_at: Time.current)
    expect(tool(topic_id: target.id, deleted: false, reason: "Testing").approval_changes).to eq(
      [{ label: "Changing status:", before: "Deleted", after: "Active" }],
    )
  end

  it "deletes the topic when deleted is true" do
    topic_id = post.topic_id

    result = tool(topic_id: topic_id, deleted: true, reason: "Spam content").invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.deleted_at).not_to be_nil
  end

  it "recovers the topic when deleted is false" do
    PostDestroyer.new(Discourse.system_user, post, context: "test setup").destroy
    post.reload

    result = tool(topic_id: post.topic_id, deleted: false, reason: "Restored after review").invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.deleted_at).to be_nil
  end

  it "returns an error when topic is not found" do
    result = tool(topic_id: -1, deleted: true, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(topic_id: post.topic_id, deleted: true, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { topic_id: post.topic_id, deleted: true, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
