# frozen_string_literal: true

RSpec.describe DiscourseAi::Automation::AiToolAction do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user, raw: "Test post content") }
  fab!(:llm_model)

  fab!(:context_tool) do
    AiTool.create!(
      name: "Context Reader",
      tool_name: "context_reader",
      description: "Reads data from context",
      parameters: [],
      script: <<~JS,
        function invoke(params) {
          const post = discourse.getPost(context.post_id);
          return {
            post_id: context.post_id,
            raw: post.raw,
            username: context.username
          };
        }
      JS
      created_by_id: Discourse.system_user.id,
      summary: "Reads context",
      enabled: true,
    )
  end

  before do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.discourse_ai_enabled = true
  end

  it "executes tool that reads from context" do
    result = described_class.handle(post: post, tool_id: context_tool.id)
    expect(result["post_id"]).to eq(post.id)
    expect(result["raw"]).to eq("Test post content")
    expect(result["username"]).to eq(user.username)
  end

  it "skips disabled tools" do
    context_tool.update!(enabled: false)
    result = described_class.handle(post: post, tool_id: context_tool.id)
    expect(result).to be_nil
  end

  it "skips non-existent tools" do
    result = described_class.handle(post: post, tool_id: -999)
    expect(result).to be_nil
  end

  context "with LLM configured" do
    fab!(:llm_tool) do
      AiTool.create!(
        name: "LLM Tool",
        tool_name: "llm_tool",
        description: "Uses LLM to generate",
        parameters: [],
        script: <<~JS,
          function invoke(params) {
            const result = llm.truncate("test string", 5);
            return { truncated: result };
          }
        JS
        created_by_id: Discourse.system_user.id,
        summary: "Uses LLM",
        enabled: true,
      )
    end

    it "passes LLM when specified" do
      result = described_class.handle(post: post, tool_id: llm_tool.id, llm_model_id: llm_model.id)
      expect(result["truncated"]).to be_present
    end
  end
end
