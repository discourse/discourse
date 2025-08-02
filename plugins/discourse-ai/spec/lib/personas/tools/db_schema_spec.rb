#frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::DbSchema do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  describe "#process" do
    it "returns rich schema for tables" do
      result = described_class.new({ tables: "posts,topics" }, bot_user: bot_user, llm: llm).invoke

      expect(result[:schema_info]).to include("raw text")
      expect(result[:schema_info]).to include("views integer")
      expect(result[:schema_info]).to include("posts")
      expect(result[:schema_info]).to include("topics")

      expect(result[:tables]).to eq("posts,topics")
    end
  end
end
