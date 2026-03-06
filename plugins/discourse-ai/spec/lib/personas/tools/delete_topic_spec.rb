# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::DeleteTopic do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
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

  let(:context) { DiscourseAi::Personas::BotContext.new }

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
end
